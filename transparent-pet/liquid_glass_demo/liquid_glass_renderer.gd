# ============================================================================
# 文件：liquid_glass_renderer.gd
# ============================================================================
# 作用：
#     本文件是液态玻璃效果的**核心渲染器**脚本。它管理一整套多阶段渲染管线
#     （Multi-Pass Rendering Pipeline），将多个 SubViewport 与自定义着色器
#     串联起来，最终在屏幕上呈现出具有折射、色散、菲涅尔效应、高光、背景
#     模糊、阴影和色调等效果的逼真液态玻璃。
#
# 设计模式：
#     - 【管线模式 (Pipeline / Chain of Responsibility)】：
#       四个 SubViewport 按固定顺序组成渲染管线，每个阶段的输出作为下一阶段
#       的输入纹理：
#         BgViewport(阴影+背景) → VBlurViewport(垂直模糊) → HBlurViewport(水平模糊)
#                                                        ↘
#                                            MainViewport(合成最终画面) → MainTexture
#     - 【策略模式 (Strategy Pattern) - 着色器分发】：
#       每个 SubViewport 绑定各自的 ShaderMaterial，执行不同的渲染策略：
#         bg_material    → 背景绘制 + 阴影 + 形状 SDF
#         vblur_material → 垂直方向高斯模糊
#         hblur_material → 水平方向高斯模糊
#         main_material  → 折射/高光/色调/菲涅尔合成
#     - 【统一更新模式 (Batch Update Pattern)】：
#       所有着色器 uniform 在 `update_all_uniforms()` 中一次性批量更新，
#       避免多次 CPU↔GPU 同步。
#
# 渲染管线详解：
#     ┌─────────────────────────────────────────────────────┐
#     │                    渲染管线流程图                      │
#     │                                                      │
#     │  Step 1: BgViewport (背景子视口)                      │
#     │  ┌──────────────────────────────────────────────┐   │
#     │  │ bg_material 着色器:                           │   │
#     │  │  · 根据 bg_type 绘制背景图案                   │   │
#     │  │  · 计算 SDF 确定玻璃形状区域                   │   │
#     │  │  · 在形状区域外绘制阴影                        │   │
#     │  │  · 输出: 背景 + 阴影的纹理                     │   │
#     │  └──────────────────────────────────────────────┘   │
#     │                         ↓                            │
#     │  Step 2: VBlurViewport (垂直模糊子视口)              │
#     │  ┌──────────────────────────────────────────────┐   │
#     │  │ vblur_material 着色器:                        │   │
#     │  │  · 对 Step 1 输出进行垂直方向高斯模糊           │   │
#     │  │  · 使用分离式卷积优化 (Separable Convolution)  │   │
#     │  │  · 输出: 垂直模糊纹理                         │   │
#     │  └──────────────────────────────────────────────┘   │
#     │                         ↓                            │
#     │  Step 3: HBlurViewport (水平模糊子视口)              │
#     │  ┌──────────────────────────────────────────────┐   │
#     │  │ hblur_material 着色器:                        │   │
#     │  │  · 对 Step 2 输出进行水平方向高斯模糊           │   │
#     │  │  · 两步分离卷积 = 等效二维高斯模糊             │   │
#     │  │  · 输出: 完全模糊的背景纹理                   │   │
#     │  └──────────────────────────────────────────────┘   │
#     │                         ↓                            │
#     │  Step 4: MainViewport (主合成子视口)                 │
#     │  ┌──────────────────────────────────────────────┐   │
#     │  │ main_material 着色器:                         │   │
#     │  │  · 计算 SDF 确定形状                          │   │
#     │  │  · 应用折射效果（采样偏移背景）                 │   │
#     │  │  · 应用色散（RGB 通道不同偏移量）              │   │
#     │  │  · 应用菲涅尔效应（边缘反射）                  │   │
#     │  │  · 应用高光（基于法线的镜面反射）              │   │
#     │  │  · 应用色调着色                              │   │
#     │  │  · 根据 blur_edge 开关选择原始/模糊背景       │   │
#     │  │  · 输出: 最终合成纹理                         │   │
#     │  └──────────────────────────────────────────────┘   │
#     │                         ↓                            │
#     │  MainTexture (TextureRect)                           │
#     │  ┌──────────────────────────────────────────────┐   │
#     │  │  · 直接将 Step 4 纹理显示到屏幕               │   │
#     │  │  · 设置 texture_filter = 2 (三线性过滤)       │   │
#     │  └──────────────────────────────────────────────┘   │
#     └─────────────────────────────────────────────────────┘
#
# 关于分离式高斯模糊 (Separable Gaussian Blur) 的数学原理：
#     二维高斯核 G(x,y) = (1/(2πσ²)) * exp(-(x²+y²)/(2σ²))
#     可以分解为两个一维核的卷积：G(x,y) = G(x) * G(y)
#     因此 O(n²) 复杂度的二维卷积被优化为两次 O(n) 的一维卷积，
#     当核半径较大时性能提升显著（例如半径 10 → 400 次采样降为 40 次）。
#
# 关于 SDF (Signed Distance Function) 的说明：
#     着色器中使用 SDF 来定义玻璃形状的轮廓和内部区域。
#     SDF 返回像素到形状边缘的有符号距离：负值表示内部，正值表示外部。
#     通过 smoothstep 将 SDF 值转换为 alpha 值，实现抗锯齿的边缘。
# ============================================================================

# ============================================================================
# 类：LiquidGlassRenderer (继承 Node2D)
# ============================================================================
# 职责：
#     - 管理多阶段渲染管线的 SubViewport 和 ShaderMaterial。
#     - 提供所有渲染参数的可调节接口（export var）。
#     - 每帧更新着色器 uniform（鼠标位置、时间、物品数据等）。
#     - 计算高斯模糊权重表。
# ============================================================================
extends Node2D

# ---------------------------------------------------------------------------
# @onready - SubViewport 节点引用
# ---------------------------------------------------------------------------
# 四个 SubViewport 分别对应渲染管线的四个阶段：
# bg_viewport:  阶段1 - 背景/阴影渲染
# vblur_viewport: 阶段2 - 垂直模糊
# hblur_viewport: 阶段3 - 水平模糊
# main_viewport:  阶段4 - 最终合成

@onready var bg_viewport: SubViewport = $RenderLayers/BgViewport
@onready var vblur_viewport: SubViewport = $RenderLayers/VBlurViewport
@onready var hblur_viewport: SubViewport = $RenderLayers/HBlurViewport
@onready var main_viewport: SubViewport = $RenderLayers/MainViewport

# ---------------------------------------------------------------------------
# @onready - ColorRect 节点引用（每个 SubViewport 的子节点）
# ---------------------------------------------------------------------------
# 每个 SubViewport 内部包含一个 ColorRect，用于承载对应的 ShaderMaterial
# 并作为全屏渲染的画布。

@onready var bg_rect: ColorRect = bg_viewport.get_child(0)
@onready var vblur_rect: ColorRect = vblur_viewport.get_child(0)
@onready var hblur_rect: ColorRect = hblur_viewport.get_child(0)
@onready var main_rect: ColorRect = main_viewport.get_child(0)

# main_texture_rect (TextureRect)
#     最终显示用的 TextureRect，绑定到 MainViewport 的输出纹理。
#     通过设置其 texture 属性，将主视口的渲染结果直接呈现到屏幕。
@onready var main_texture_rect: TextureRect = $MainTexture

# ---------------------------------------------------------------------------
# @onready - ShaderMaterial 引用
# ---------------------------------------------------------------------------
# 从各 ColorRect 的 material 属性中获取 ShaderMaterial 引用。
# 使用 `as ShaderMaterial` 进行类型转换确保安全。

@onready var bg_material: ShaderMaterial = bg_rect.material as ShaderMaterial
@onready var vblur_material: ShaderMaterial = vblur_rect.material as ShaderMaterial
@onready var hblur_material: ShaderMaterial = hblur_rect.material as ShaderMaterial
@onready var main_material: ShaderMaterial = main_rect.material as ShaderMaterial

# ============================================================================
# @export 变量 - 折射参数组 (Refraction)
# ============================================================================
# 折射效果基于 Snell 定律模拟。光线从一种介质进入另一种介质时，
# 传播方向发生偏折。偏折角度由两个介质的折射率比决定。
#
# 在着色器中的实现：
#   对每个像素，计算其到玻璃边缘的距离，将距离映射为 UV 偏移量。
#   偏移后的 UV 用于采样背景纹理，从而产生"折射"的视觉效果。
#
# 公式（简化的着色器实现）：
#   offset = sdf_edge_dist * ref_thickness * ref_factor
#   refracted_uv = original_uv + offset * normal_dir

# ref_thickness (float)
#     折射厚度，默认 20.0 像素。
#     控制光线在玻璃介质中传播产生的偏移幅度。
#     物理对应：介质的物理厚度（d）。偏移量与厚度成正比。
@export var ref_thickness: float = 20.0

# ref_factor (float)
#     折射因子，默认 1.4（接近玻璃的折射率）。
#     控制折射偏移的强度倍率。
#     物理对应：第二种介质（玻璃）相对第一种介质（空气）的折射率比。
#     常见材质折射率：空气=1.0，水=1.33，玻璃=1.4~1.6，钻石=2.42。
@export var ref_factor: float = 1.4

# ref_dispersion (float)
#     色散强度，默认 7.0。
#     控制 RGB 三通道折射偏移的差异程度。
#     物理原理：由于色散，不同波长的光折射率不同。短波长（蓝色）折射率更高。
#     在着色器中，对 R 通道偏移量最小，G 通道中等，B 通道偏移量最大。
#     这会在边缘产生彩虹状的彩色条纹效果。
@export var ref_dispersion: float = 7.0

# ref_fresnel_range (float)
#     菲涅尔范围，默认 30.0 像素。
#     控制菲涅尔效应从中心到边缘的过渡区域宽度。
#     在着色器中，使用像素到边缘的距离与 ref_fresnel_range 的比值
#     通过 smoothstep 决定菲涅尔混合因子。
@export var ref_fresnel_range: float = 30.0

# ref_fresnel_hardness (float)
#     菲涅尔硬度，默认 0.2（范围 0.0~1.0）。
#     控制菲涅尔过渡的陡峭程度。
#     0.0 → 极其柔和的渐变；1.0 → 非常锐利的硬边缘过渡。
#     在着色器中作为 smoothstep 的边缘参数。
@export var ref_fresnel_hardness: float = 0.2

# ref_fresnel_factor (float)
#     菲涅尔强度因子，默认 0.2（范围 0.0~1.0）。
#     控制边缘反射的强度比例。
#     0.0 → 中心到边缘均匀折射（无菲涅尔效果）；
#     1.0 → 边缘完全反射原始背景，中心区域折射。
#     物理原理：菲涅尔方程描述，入射角越大（越接近边缘掠射），反射率越高。
@export var ref_fresnel_factor: float = 0.2

# ============================================================================
# @export 变量 - 高光参数组 (Glare / Specular Highlight)
# ============================================================================
# 高光模拟玻璃表面对光源的镜面反射。基于 Phong/Blinn-Phong 光照模型的
# 简化实现，使用 SDF 梯度的近似作为表面法线。
#
# 在着色器中的原理：
#   1. 从 SDF 计算形状边缘梯度向量（近似法线）。
#   2. 计算光源方向与法线的点积（dot product），得到光照因子。
#   3. 光照因子经过 power 运算（控制汇聚度）和 smoothstep 映射，
#      产生边缘高光条。

# glare_range (float)
#     高光范围，默认 30.0 像素。
#     高光从形状边缘向内延伸的距离。
@export var glare_range: float = 30.0

# glare_hardness (float)
#     高光硬度，默认 0.2（范围 0.0~1.0）。
#     控制高光边缘的柔和度。值越小，高光过渡越柔和。
@export var glare_hardness: float = 0.2

# glare_convergence (float)
#     高光汇聚度，默认 0.5（范围 0.0~1.0）。
#     控制高光向光源方向汇聚的强度。
#     0.0 → 高光均匀分布在所有边缘；
#     1.0 → 高光仅出现在正对光源的边缘。
#     着色器中使用 pow(dot_result, convergence_exponent) 实现。
@export var glare_convergence: float = 0.5

# glare_opposite_factor (float)
#     反向高光因子，默认 0.8（范围 0.0~1.0）。
#     控制背光面（与光源方向相反）的高光强度。
#     0.0 → 只有正面高光；1.0 → 正面和背面高光强度相同。
#     模拟次表面散射（SSS）效果。
@export var glare_opposite_factor: float = 0.8

# glare_factor (float)
#     高光强度，默认 0.9（范围 0.0~1.0）。
#     控制高光的整体亮度。
#     0.0 → 无高光；1.0 → 最强高光（纯白色）。
@export var glare_factor: float = 0.9

# glare_angle (float)
#     高光角度，默认 -45.0°（角度制）。
#     定义光源在屏幕空间中的方向角度。
#     -45° 表示光源来自左上方（典型桌面环境的光源方向）。
#     在着色器中通过 `deg_to_rad()` 转换为弧度用于三角函数计算。
@export var glare_angle: float = -45.0

# ============================================================================
# @export 变量 - 模糊参数组 (Blur)
# ============================================================================
# 背景模糊通过分离式高斯模糊实现。分离式卷积利用二维高斯核的可分离性，
# 将 O(n²) 复杂度的二维卷积分解为两次 O(n) 的一维卷积。
#
# 渲染管线中的实现：
#   bg_texture → [垂直模糊着色器] → vblur_texture → [水平模糊着色器] → 最终模糊纹理

# blur_radius (float)
#     模糊半径，默认 1.0 像素。
#     高斯核的半径，控制模糊程度。
#     对应高斯函数中的 σ = radius / 3.0（3σ 原则覆盖约 99.7% 的能量）。
@export var blur_radius: float = 1.0

# blur_edge (bool)
#     边缘模糊开关，默认 true。
#     true  → 形状内部使用模糊背景，边缘有柔和的模糊过渡。
#     false → 形状内部直接折射原始背景（无模糊，清晰的透镜效果）。
@export var blur_edge: bool = true

# ============================================================================
# @export 变量 - 色调参数组 (Tint)
# ============================================================================
# 色调模拟有色玻璃效果。在着色器中通过对折射后的背景颜色与 tint 颜色
# 进行混合实现。

# tint (Color)
#     色调颜色，默认白色（无色）。
#     选择有色玻璃的颜色，如茶色→暖黄，蓝色→冷蓝。
@export var tint: Color = Color.WHITE

# tint_alpha (float)
#     色调不透明度，默认 0.0（范围 0.0~1.0）。
#     控制色调颜色的混合强度。
#     0.0 → 无色（完全透明）；1.0 → 不透明着色。
@export var tint_alpha: float = 0.0

# ============================================================================
# @export 变量 - 形状融合参数 (Shape Merge)
# ============================================================================

# merge_rate (float)
#     合并速率，默认 0.05（范围 0.0~1.0）。
#     当多个玻璃形状重叠时，它们的有符号距离场 (SDF) 通过
#     smooth minimum 函数进行融合。merge_rate 控制融合的平滑程度。
#     0.0 → 形状保持独立边界（硬边缘交叠）；
#     1.0 → 形状完全融合为一个整体（类似液体合并）。
#     数学上使用多项式平滑最小值函数：
#       smin(a, b, k) = min(a, b) - max(k - |a-b|, 0)² / (2k)
@export var merge_rate: float = 0.05

# ============================================================================
# @export 变量 - 阴影参数组 (Shadow)
# ============================================================================
# 阴影在背景着色器（bg_material）中计算。基于 SDF 值，在形状外部区域
# 添加半透明的暗色覆盖。

# shadow_expand (float)
#     阴影扩展，默认 25.0 像素。
#     控制阴影从形状边缘向外延伸的距离。
@export var shadow_expand: float = 25.0

# shadow_factor (float)
#     阴影强度，默认 0.15（范围 0.0~1.0）。
#     控制阴影的不透明度。
#     0.0 → 无阴影；1.0 → 最深阴影。
@export var shadow_factor: float = 0.15

# shadow_position (Vector2)
#     阴影偏移，默认 (0, -10) 像素。
#     控制阴影相对于形状的偏移方向。
#     默认值 (0, -10) 表示阴影向上偏移 10 像素（模拟顶部光源）。
#     阴影偏移基于 SDF 的梯度方向（即形状表面的法线方向）。
@export var shadow_position: Vector2 = Vector2(0, -10)

# ============================================================================
# @export 变量 - 背景类型 (Background)
# ============================================================================

# bg_type (int)
#     背景类型索引，默认 0（棋盘格）。
#     0 - 棋盘格 (Checkerboard)：经典透明背景指示器。
#     1 - 分块 (Blocks)：不同颜色的大方块，便于观察折射偏移幅度。
#     2 - 渐变 (Gradient)：平滑渐变色。
#     3 - 透明 (Transparent)：纯透明背景，用于桌面宠物模式。
@export var bg_type: int = 0

# ---------------------------------------------------------------------------
# 内部状态变量
# ---------------------------------------------------------------------------

# mouse_position (Vector2)
#     当前帧的鼠标物理像素坐标。
#     用于着色器中的折射方向计算和高光方向确定。
var mouse_position: Vector2 = Vector2.ZERO

# mouse_spring (Vector2)
#     鼠标弹簧位置（惯性追踪位置），物理像素坐标。
#     着色器使用 `mix(mouse_spring, mouse_position, merge_rate)` 实现
#     平滑的鼠标追踪效果，避免鼠标快速移动时玻璃形状抖动。
#     物理模拟：类似带有阻尼的弹簧系统。merge_rate 对应弹簧刚度。
var mouse_spring: Vector2 = Vector2.ZERO

# blur_weights (PackedFloat32Array)
#     预计算的高斯模糊权重表。
#     通过 `compute_gaussian_kernel()` 根据当前 blur_radius 计算。
#     权重表在每帧的 `_process()` 中更新，以响应动态变化的模糊半径。
#     数组长度 = int(blur_radius * 2) + 1（覆盖 ±radius 的范围）。
var blur_weights: PackedFloat32Array = PackedFloat32Array()

# ============================================================================
# 物品管理器
# ============================================================================

# item_manager (GlassItemManager)
#     管理场景中所有玻璃物品的单例管理器。
#     负责物品的增删查改、选中拖拽和着色器数据打包。
#     渲染器通过 `get_items()` 获取物品列表来更新着色器 uniform。
var item_manager: GlassItemManager = GlassItemManager.new()

# MAX_ITEMS (int)
#     最大物品数量，与着色器端数组长度一致。
#     必须以 `const` 定义以确保编译时常量优化。
const MAX_ITEMS: int = 3

# ============================================================================
# 方法：_ready()
# ============================================================================
# 参数：无
# 返回值：无
#
# 核心逻辑（初始化渲染管线）：
#     1. 将 MainTexture (TextureRect) 的纹理源绑定到 MainViewport 的输出。
#        这是管线最终输出到屏幕的关键连接。
#     2. 更新所有 SubViewport 的尺寸，确保与窗口物理分辨率一致。
#     3. 初始化高斯模糊权重表。
#     4. 创建默认物品（圆形、圆角矩形、史莱姆各一个）。
#     5. 将物品数据打包为着色器 uniform 数组。
#     6. 连接视口尺寸变化信号，实现响应式布局。
# ============================================================================
func _ready():
	main_texture_rect.texture = main_viewport.get_texture()

	# 注意：texture_filter 在 .tscn 文件中设置 (MainTexture 节点的 texture_filter = 2)
	# 2 = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS（三线性过滤），确保缩放时画质最佳。

	update_viewport_sizes()
	update_blur_weights()

	init_default_items()
	update_items_uniforms()

	get_viewport().size_changed.connect(_on_viewport_resize)

# ============================================================================
# 方法：init_default_items()
# ============================================================================
# 参数：无
# 返回值：无
#
# 核心逻辑：
#     计算物理像素视口尺寸，调用 item_manager 创建默认物品布局。
#     DPR 用于确保物品尺寸在不同像素密度的显示器上视觉一致。
# ============================================================================
func init_default_items():
	var dpr: float = get_tree().root.content_scale_factor
	var viewport_size = Vector2(get_viewport().size.x * dpr, get_viewport().size.y * dpr)
	item_manager.init_default_items(viewport_size)

# ============================================================================
# 方法：update_viewport_sizes()
# ============================================================================
# 参数：无
# 返回值：无
#
# 核心逻辑：
#     将所有 SubViewport 的渲染分辨率同步为视口的物理像素尺寸。
#     必须乘以 DPR 以确保在高 DPI 显示器上渲染不会模糊。
#
#     使用 Vector2i（整数类型）存储视口尺寸，因为 SubViewport.size
#     只能接受整数像素值。
# ============================================================================
func update_viewport_sizes():
	var viewport_size: Vector2i = get_viewport().size
	var dpr: float = get_tree().root.content_scale_factor

	bg_viewport.size = Vector2i(int(viewport_size.x * dpr), int(viewport_size.y * dpr))
	vblur_viewport.size = Vector2i(int(viewport_size.x * dpr), int(viewport_size.y * dpr))
	hblur_viewport.size = Vector2i(int(viewport_size.x * dpr), int(viewport_size.y * dpr))
	main_viewport.size = Vector2i(int(viewport_size.x * dpr), int(viewport_size.y * dpr))

# ============================================================================
# 方法：_on_viewport_resize()
# ============================================================================
# 参数：无
# 返回值：无
#
# 核心逻辑（窗口缩放响应）：
#     当用户拖拽窗口边缘改变大小时触发。
#     1. 更新所有 SubViewport 的分辨率以匹配新窗口尺寸。
#     2. 统一刷新所有着色器 uniform（特别是 u_resolution 和物品位置）。
# ============================================================================
func _on_viewport_resize():
	update_viewport_sizes()
	update_all_uniforms()

# ============================================================================
# 方法：compute_gaussian_kernel(radius: float) → PackedFloat32Array
# ============================================================================
# 参数：
#     radius (float) - 高斯模糊的核半径（像素）。
#
# 返回值：
#     PackedFloat32Array - 归一化的高斯权重数组。
#                          长度为 int(radius * 2) + 1。
#                          所有权重之和 = 1.0。
#
# 核心逻辑（一维高斯核计算）：
#     1. 计算 sigma：σ = radius / 3.0。
#        "3σ 原则" 确保核覆盖约 99.7% 的高斯分布能量。
#     2. 对核内每个位置 i（共 2*radius + 1 个采样点），计算：
#        x = i - radius（将采样位置映射到以 0 为中心的坐标系）
#        weight = exp(-x² / (2σ²))
#     3. 归一化：所有权重除以总权重值，确保卷积后亮度不变。
#
# 数学原理 - 一维高斯函数：
#     G(x) = (1 / (σ * sqrt(2π))) * exp(-x² / (2σ²))
#     由于之后会归一化，这里省略了前面的常数因子 1/(σ√(2π))。
#
# 为什么使用分离卷积？
#     二维高斯核：G(x,y) = G(x) × G(y)（可分离性）
#     直接二维卷积：O(n²) 次纹理采样
#     分离卷积：O(2n) 次纹理采样（n 为核宽度）
#     例如 radius=10: 二维卷积需 21×21=441 次采样，分离卷积仅需 21+21=42 次。
# ============================================================================
func compute_gaussian_kernel(radius: float) -> PackedFloat32Array:
	var sigma: float = radius / 3.0
	var weights: PackedFloat32Array = PackedFloat32Array()
	var total_weight: float = 0.0

	for i in range(int(radius * 2) + 1):
		var x: float = float(i) - radius
		var weight: float = exp(-x * x / (2.0 * sigma * sigma))
		weights.append(weight)
		total_weight += weight

	for i in range(weights.size()):
		weights[i] /= total_weight

	return weights

# ============================================================================
# 方法：update_blur_weights()
# ============================================================================
# 参数：无
# 返回值：无
#
# 核心逻辑：
#     根据当前的 blur_radius 重新计算高斯权重表。
#     每次模糊半径变更时调用，因为 sigma 和核大小都依赖于半径。
# ============================================================================
func update_blur_weights():
	blur_weights = compute_gaussian_kernel(blur_radius)

# ============================================================================
# 方法：update_all_uniforms()
# ============================================================================
# 参数：无
# 返回值：无
#
# 核心逻辑（渲染管线参数同步）：
#     这是整个渲染器中最重要的方法之一。它将所有 CPU 端的参数一次性
#     批量打包为着色器 uniform 变量，推送到 GPU。
#
#     处理顺序严格遵循渲染管线的数据流方向：
#
#     【阶段1 - 背景着色器 (bg_material)】
#       · 分辨率 (u_resolution)：决定着色器中的坐标映射。
#       · DPR (u_dpr)：用于逻辑像素到物理像素的换算。
#       · 时间 (u_time)：驱动动画效果（如史莱姆蠕动）。
#       · 阴影参数 (u_shadowExpand/ShadowFactor/ShadowPosition)：
#         在形状 SDF 外部区域绘制半透明阴影。
#       · 背景类型 (u_bgType)：选择棋盘格/分块/渐变/透明。
#       · 形状纹理 (u_shapeTexture)：从 main_viewport 采样 SDF 纹理。
#
#     【阶段2 - 垂直模糊着色器 (vblur_material)】
#       · 模糊权重 (u_blurWeights)：预计算的高斯核权重表。
#       · 垂直标记 (u_vertical = true)：控制采样方向为垂直。
#       · 上一阶段纹理 (u_prevPassTexture)：bg_viewport 的输出。
#
#     【阶段3 - 水平模糊着色器 (hblur_material)】
#       · 同阶段2，但 u_vertical = false（水平方向采样）。
#       · u_prevPassTexture：vblur_viewport 的输出。
#
#     【阶段4 - 主合成着色器 (main_material)】
#       折射/高光/菲涅尔/色调/模糊/形状融合的完整参数集。
#       另外还传递了：
#         - 未模糊背景 (u_bg)：用于 blur_edge=false 时的清晰折射。
#         - 完全模糊背景 (u_blurredBg)：用于 blur_edge=true 时的模糊折射。
#         - STEP (9)：迭代步数，控制 SDF 射线行进的精度。
# ============================================================================
func update_all_uniforms():
	var dpr: float = get_tree().root.content_scale_factor
	var resolution: Vector2 = Vector2(get_viewport().size.x * dpr, get_viewport().size.y * dpr)

	bg_material.set_shader_parameter("u_resolution", resolution)
	bg_material.set_shader_parameter("u_dpr", dpr)
	bg_material.set_shader_parameter("u_time", Time.get_ticks_msec() / 1000.0)
	bg_material.set_shader_parameter("u_shadowExpand", shadow_expand)
	bg_material.set_shader_parameter("u_shadowFactor", shadow_factor)
	bg_material.set_shader_parameter("u_shadowPosition", shadow_position)
	bg_material.set_shader_parameter("u_bgType", bg_type)
	bg_material.set_shader_parameter("u_shapeTexture", main_viewport.get_texture())

	vblur_material.set_shader_parameter("u_resolution", resolution)
	vblur_material.set_shader_parameter("u_dpr", dpr)
	vblur_material.set_shader_parameter("u_blurRadius", blur_radius)
	vblur_material.set_shader_parameter("u_blurWeights", blur_weights)
	vblur_material.set_shader_parameter("u_vertical", true)
	vblur_material.set_shader_parameter("u_prevPassTexture", bg_viewport.get_texture())

	hblur_material.set_shader_parameter("u_resolution", resolution)
	hblur_material.set_shader_parameter("u_dpr", dpr)
	hblur_material.set_shader_parameter("u_blurRadius", blur_radius)
	hblur_material.set_shader_parameter("u_blurWeights", blur_weights)
	hblur_material.set_shader_parameter("u_vertical", false)
	hblur_material.set_shader_parameter("u_prevPassTexture", vblur_viewport.get_texture())

	main_material.set_shader_parameter("u_resolution", resolution)
	main_material.set_shader_parameter("u_dpr", dpr)
	main_material.set_shader_parameter("u_mouse", mouse_position)
	main_material.set_shader_parameter("u_mouseSpring", mouse_spring)
	main_material.set_shader_parameter("u_mergeRate", merge_rate)
	main_material.set_shader_parameter("u_tint", Color(tint.r, tint.g, tint.b, tint_alpha))
	main_material.set_shader_parameter("u_refThickness", ref_thickness)
	main_material.set_shader_parameter("u_refFactor", ref_factor)
	main_material.set_shader_parameter("u_refDispersion", ref_dispersion)
	main_material.set_shader_parameter("u_refFresnelRange", ref_fresnel_range)
	main_material.set_shader_parameter("u_refFresnelHardness", ref_fresnel_hardness)
	main_material.set_shader_parameter("u_refFresnelFactor", ref_fresnel_factor)
	main_material.set_shader_parameter("u_glareRange", glare_range)
	main_material.set_shader_parameter("u_glareConvergence", glare_convergence)
	main_material.set_shader_parameter("u_glareOppositeFactor", glare_opposite_factor)
	main_material.set_shader_parameter("u_glareFactor", glare_factor)
	main_material.set_shader_parameter("u_glareHardness", glare_hardness)
	main_material.set_shader_parameter("u_glareAngle", deg_to_rad(glare_angle))
	main_material.set_shader_parameter("u_blurEdge", 1 if blur_edge else 0)
	main_material.set_shader_parameter("STEP", 9)
	main_material.set_shader_parameter("u_bg", bg_viewport.get_texture())
	main_material.set_shader_parameter("u_blurredBg", hblur_viewport.get_texture())

	update_items_uniforms()

# ============================================================================
# 方法：set_mouse_position(pos: Vector2)
# ============================================================================
# 参数：
#     pos (Vector2) - 当前鼠标的物理像素坐标。
#
# 返回值：无
#
# 核心逻辑：
#     更新鼠标当前位置。此值用于着色器中的折射方向、高光方向和
#     史莱姆形状的弹性形变计算。每帧在 _process() 和 _input() 中调用。
# ============================================================================
func set_mouse_position(pos: Vector2):
	mouse_position = pos

# ============================================================================
# 方法：set_mouse_spring(pos: Vector2)
# ============================================================================
# 参数：
#     pos (Vector2) - 弹簧追踪目标的物理像素坐标。
#
# 返回值：无
#
# 核心逻辑：
#     更新鼠标弹簧追踪目标。着色器中通过 `mix(mouse_spring, mouse_position, merge_rate)`
#     实现从 spring 位置向实际鼠标位置的平滑过渡（指数衰减追踪）。
#     这种机制模拟了物理弹簧系统：
#       弹簧力 = -k * (spring_pos - mouse_pos)  （胡克定律）
#       每帧弹簧位置向鼠标位置逼近一定比例，视觉上产生惯性拖尾效果。
# ============================================================================
func set_mouse_spring(pos: Vector2):
	mouse_spring = pos

# ============================================================================
# 方法：_process(_delta: float)
# ============================================================================
# 参数：
#     _delta (float) - 上一帧到当前帧的时间间隔（秒）。前缀 _ 表示未使用。
#
# 返回值：无
#
# 核心逻辑（每帧更新）：
#     1. 更新时间 uniform（bg_material 用于动画，main_material 用于动态效果）。
#     2. 更新鼠标位置和弹簧位置 uniform（实时交互）。
#     3. 重新计算高斯模糊权重表（因为 blur_radius 可能被控制面板修改）。
#     4. 更新物品数据 uniform（物品可能被拖拽移动）。
#
# 为什么分两个着色器设置鼠标相关 uniform？
#     bg_material 中的鼠标位置用于阴影偏移动画。
#     main_material 中的鼠标位置用于折射方向、高光和形变。
# ============================================================================
func _process(_delta: float):
	bg_material.set_shader_parameter("u_time", Time.get_ticks_msec() / 1000.0)
	bg_material.set_shader_parameter("u_mouse", mouse_position)
	bg_material.set_shader_parameter("u_mouseSpring", mouse_spring)
	main_material.set_shader_parameter("u_mouse", mouse_position)
	main_material.set_shader_parameter("u_mouseSpring", mouse_spring)
	update_blur_weights()

	update_items_uniforms()

# ============================================================================
# 方法：update_items_uniforms()
# ============================================================================
# 参数：无
# 返回值：无
#
# 核心逻辑（物品数据打包为着色器数组）：
#     这是 CPU→GPU 数据桥接的关键方法。它将 GlassItemManager 中存储的
#     所有物品对象的属性转换为 8 个固定长度的 PackedArray，然后作为
#     uniform 数组传递给 bg_material 和 main_material 着色器。
#
#     8 个数组的对应关系（GPU 端按索引并行读取）：
#     ┌──────────────────────┬────────────────┬──────────────────┐
#     │ GDScript 数组名       │ 着色器 uniform  │ 数据类型          │
#     ├──────────────────────┼────────────────┼──────────────────┤
#     │ u_itemPositions[i]   │ vec2[3]        │ 物品中心坐标       │
#     │ u_itemWidths[i]      │ float[3]       │ 物品宽度           │
#     │ u_itemHeights[i]     │ float[3]       │ 物品高度           │
#     │ u_itemRadii[i]       │ float[3]       │ 圆角/圆半径        │
#     │ u_itemRoundness[i]   │ float[3]       │ 圆滑度             │
#     │ u_itemShapeTypes[i]  │ float[3]       │ 形状类型(0/1/2)   │
#     │ u_itemEnabled[i]     │ float[3]       │ 启用标志(0.0/1.0) │
#     │ u_itemScales[i]      │ float[3]       │ 缩放因子           │
#     └──────────────────────┴────────────────┴──────────────────┘
#
#     为什么需要填充到 MAX_ITEMS 长度？
#     GPU 着色器中的 uniform 数组必须是固定长度的。如果实际物品数量
#     不足 MAX_ITEMS，剩余槽位用全零值填充。enabled=0.0 的槽位在
#     着色器中被跳过，不会产生视觉输出。
# ============================================================================
func update_items_uniforms():
	var items = item_manager.get_items()

	var positions: PackedVector2Array = PackedVector2Array()
	var widths: PackedFloat32Array = PackedFloat32Array()
	var heights: PackedFloat32Array = PackedFloat32Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var roundness: PackedFloat32Array = PackedFloat32Array()
	var shapeTypes: PackedFloat32Array = PackedFloat32Array()
	var enabled: PackedFloat32Array = PackedFloat32Array()
	var scales: PackedFloat32Array = PackedFloat32Array()

	for i in range(MAX_ITEMS):
		if i < items.size():
			var item = items[i]
			positions.append(item.position)
			widths.append(item.width)
			heights.append(item.height)
			radii.append(item.radius)
			roundness.append(item.roundness)
			shapeTypes.append(float(item.shape_type))
			enabled.append(1.0 if item.enabled else 0.0)
			scales.append(item.scale)
		else:
			positions.append(Vector2.ZERO)
			widths.append(0.0)
			heights.append(0.0)
			radii.append(0.0)
			roundness.append(0.0)
			shapeTypes.append(0.0)
			enabled.append(0.0)
			scales.append(0.0)

	bg_material.set_shader_parameter("u_itemPositions", positions)
	bg_material.set_shader_parameter("u_itemWidths", widths)
	bg_material.set_shader_parameter("u_itemHeights", heights)
	bg_material.set_shader_parameter("u_itemRadii", radii)
	bg_material.set_shader_parameter("u_itemRoundness", roundness)
	bg_material.set_shader_parameter("u_itemShapeTypes", shapeTypes)
	bg_material.set_shader_parameter("u_itemEnabled", enabled)
	bg_material.set_shader_parameter("u_itemScales", scales)

	main_material.set_shader_parameter("u_itemPositions", positions)
	main_material.set_shader_parameter("u_itemWidths", widths)
	main_material.set_shader_parameter("u_itemHeights", heights)
	main_material.set_shader_parameter("u_itemRadii", radii)
	main_material.set_shader_parameter("u_itemRoundness", roundness)
	main_material.set_shader_parameter("u_itemShapeTypes", shapeTypes)
	main_material.set_shader_parameter("u_itemEnabled", enabled)
	main_material.set_shader_parameter("u_itemScales", scales)

# ============================================================================
# 方法：get_item_manager() → GlassItemManager
# ============================================================================
# 参数：无
#
# 返回值：
#     GlassItemManager - 渲染器持有的物品管理器实例。
#
# 核心逻辑：
#     暴露物品管理器给外部（main.gd 等），使其能够进行物品选择和拖拽操作。
# ============================================================================
func get_item_manager() -> GlassItemManager:
	return item_manager
