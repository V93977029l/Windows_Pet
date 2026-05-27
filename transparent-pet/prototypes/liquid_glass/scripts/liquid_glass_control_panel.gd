# ============================================================================
# 文件：liquid_glass_control_panel.gd
# ============================================================================
# 作用：
#     本文件定义了液态玻璃效果的控制面板脚本。它挂载在一个 PanelContainer
#     节点上，提供了一系列 UI 控件（滑块、复选框、颜色选择器、下拉菜单）
#     用于实时调节液态玻璃渲染的各项参数。
#
# 设计模式：
#     - 【桥接模式 (Bridge Pattern)】：控制面板作为一种"桥"，将用户对
#       UI 控件的操作翻译为对渲染器属性的修改。UI 控件本身不知道
#       渲染器的存在，所有连接在脚本中手动建立。
#     - 【观察者模式 (Observer Pattern) - 信号连接】：每个 UI 控件的
#       .tscn 场景文件中预设了信号连接到本脚本的对应方法（如
#       `_on_ref_thickness_changed` 等）。控件的值变化自动触发对应的
#       回调方法，无需手动轮询。
#
# 架构说明：
#     控制面板通过 `$VBoxContainer/分组名/参数名/控件名` 的层级结构组织。
#     所有控件分为以下几大组：
#       - Refraction  （折射）：折射厚度、折射因子、色散、菲涅尔参数
#       - Glare       （高光）：高光范围/硬度/强度/汇聚度/反向因子/角度
#       - Blur        （模糊）：模糊半径、边缘模糊开关
#       - Tint        （色调）：色调颜色、不透明度
#       - Shape       （形状）：合并速率
#       - Shadow      （阴影）：阴影扩展/强度/偏移 X/Y
#       - Background  （背景）：背景类型选择
#
#     关于数值映射的说明：
#     - 部分着色器参数的值域为 [0.0, 1.0]，但滑块为整数便于操作用 [0, 100]，
#       因此需要在信号处理中做 `/ 100.0` 或 `* 100.0` 的转换。
#     - 角度值在 CPU 端为角度制（更直观），但在 `update_all_uniforms()` 中
#       会用 `deg_to_rad()` 转换为弧度制传给着色器（着色器使用弧度）。
#     - 某些值域本身较大（如 ref_thickness 范围 0~200），直接使用原始值
#       传递，不做缩放。
# ============================================================================

# ============================================================================
# 类：控制面板 (继承 PanelContainer)
# ============================================================================
# 职责：
#     - 初始化所有控件的默认值（从渲染器读取当前参数同步）。
#     - 响应用户对控件的操作，将数值/状态写回渲染器。
#     - 每次参数变更后通知渲染器统一刷新所有着色器 uniform。
# ============================================================================
extends PanelContainer

# ---------------------------------------------------------------------------
# @onready - 渲染器引用
# ---------------------------------------------------------------------------

# renderer (Node2D)
#     对父节点的 `LiquidGlassRenderer` 子节点的引用。
#     所有参数修改都通过此引用传递给渲染器。
@onready var renderer: Node2D = get_parent().get_node("LiquidGlassRenderer")

# ---------------------------------------------------------------------------
# @onready - 折射组 (Refraction) 控件
# ---------------------------------------------------------------------------

# ref_thickness_slider (HSlider)
#     折射厚度：控制光线穿过玻璃时产生的偏移量大小。
#     单位为像素。值越大，玻璃后的背景看起来偏离越远。
#     物理对应：玻璃材质的光学厚度（物理厚度 × 折射率）。
@onready var ref_thickness_slider: HSlider = $VBoxContainer/Refraction/RefThickness/HSlider

# ref_factor_slider (HSlider)
#     折射因子（折射率比值）：控制光线从空气进入玻璃时的偏折角度。
#     值 1.0 表示无折射，值越大折射越强。
#     物理对应：Snell定律中的折射率比 n₂/n₁。
@onready var ref_factor_slider: HSlider = $VBoxContainer/Refraction/RefFactor/HSlider

# ref_dispersion_slider (HSlider)
#     色散强度：模拟白光通过棱镜分解为彩虹色带的效应。
#     值越大，R/G/B 三个通道的折射偏移差异越大，色散越明显。
#     物理原理：不同波长的光在同一介质中折射率略有不同（色散），
#     蓝色光折射更多（偏移大），红色光折射更少（偏移小）。
@onready var ref_dispersion_slider: HSlider = $VBoxContainer/Refraction/RefDispersion/HSlider

# ref_fresnel_range_slider (HSlider)
#     菲涅尔范围：控制菲涅尔效应过渡区域的宽度。
#     值越大，从中心到边缘的菲涅尔渐变跨度越大。
@onready var ref_fresnel_range_slider: HSlider = $VBoxContainer/Refraction/FresnelRange/HSlider

# ref_fresnel_hardness_slider (HSlider)
#     菲涅尔硬度：控制菲涅尔效应的锐利程度（过渡曲线的陡峭度）。
#     值越大，边缘反射越锐利（硬边界）；越小则渐变越柔和。
@onready var ref_fresnel_hardness_slider: HSlider = $VBoxContainer/Refraction/FresnelHardness/HSlider

# ref_fresnel_factor_slider (HSlider)
#     菲涅尔强度因子：控制边缘反射相对于中心折射的强度对比。
#     0.0 → 无菲涅尔效果（全折射）；1.0 → 最大菲涅尔效果（边缘强反射）。
@onready var ref_fresnel_factor_slider: HSlider = $VBoxContainer/Refraction/FresnelFactor/HSlider

# ---------------------------------------------------------------------------
# @onready - 高光组 (Glare) 控件
# ---------------------------------------------------------------------------

# glare_range_slider (HSlider)
#     高光范围：控制玻璃表面高光区域从边缘向内延伸的距离。
#     值越大，高光区域越大（像素）。
@onready var glare_range_slider: HSlider = $VBoxContainer/Glare/GlareRange/HSlider

# glare_hardness_slider (HSlider)
#     高光硬度：控制高光边缘的锐利程度。
#     值越小 → 柔和渐变过渡；值越大 → 锐利清晰边界。
@onready var glare_hardness_slider: HSlider = $VBoxContainer/Glare/GlareHardness/HSlider

# glare_factor_slider (HSlider)
#     高光强度：控制高光亮度和可见程度。
#     0.0 → 无高光；1.0 → 最强高光（纯白色）。
@onready var glare_factor_slider: HSlider = $VBoxContainer/Glare/GlareFactor/HSlider

# glare_convergence_slider (HSlider)
#     高光汇聚度：控制高光向光源方向收敛的程度。
#     值越小 → 高光分散在更大的边缘区域；
#     值越大 → 高光集中在朝向光源的狭窄区域。
@onready var glare_convergence_slider: HSlider = $VBoxContainer/Glare/GlareConvergence/HSlider

# glare_opposite_factor_slider (HSlider)
#     反向高光因子：控制与光源反方向的背光高光的强度。
#     模拟次表面散射（Subsurface Scattering）效果，光线穿透玻璃后
#     在背面散射出柔和的光晕。
@onready var glare_opposite_factor_slider: HSlider = $VBoxContainer/Glare/GlareOpposite/HSlider

# glare_angle_slider (HSlider)
#     高光角度：光源方向的角度（角度制）。
#     -45.0° → 光源在左上方（默认，模拟典型桌面光照）。
#     着色器中使用 `dot(normal, light_dir)` 计算光照因子。
@onready var glare_angle_slider: HSlider = $VBoxContainer/Glare/GlareAngle/HSlider

# ---------------------------------------------------------------------------
# @onready - 模糊组 (Blur) 控件
# ---------------------------------------------------------------------------

# blur_radius_slider (HSlider)
#     模糊半径：控制背景模糊的核大小（像素）。
#     值越大，玻璃背后的背景越模糊。
#     对应渲染流水线中分离式高斯模糊的 sigma 参数。
@onready var blur_radius_slider: HSlider = $VBoxContainer/Blur/BlurRadius/HSlider

# blur_edge_check (CheckBox)
#     边缘模糊开关：
#     - 勾选 → 启用边缘模糊（形状边缘附近的模糊过渡更柔和）。
#     - 未勾选 → 仅折射但不模糊（清晰的透镜效果）。
@onready var blur_edge_check: CheckBox = $VBoxContainer/Blur/BlurEdge/CheckBox

# ---------------------------------------------------------------------------
# @onready - 色调组 (Tint) 控件
# ---------------------------------------------------------------------------

# tint_color_picker (ColorPickerButton)
#     色调颜色选择器：选择玻璃的整体颜色偏差。
#     模拟有色玻璃效果（如茶色玻璃、蓝色玻璃）。
@onready var tint_color_picker: ColorPickerButton = $VBoxContainer/Tint/TintColor/ColorPickerButton

# tint_alpha_slider (HSlider)
#     色调不透明度：控制色调颜色的强度。
#     0.0 → 无色（完全透明玻璃）；1.0 → 完全不透明（着色覆盖整个形状）。
@onready var tint_alpha_slider: HSlider = $VBoxContainer/Tint/TintAlpha/HSlider

# ---------------------------------------------------------------------------
# @onready - 形状组 (Shape) 控件
# ---------------------------------------------------------------------------

# merge_rate_slider (HSlider)
#     合并速率：控制多个玻璃形状重叠区域的过渡平滑度。
#     值越小 → 形状交界清晰；值越大 → 形状交界平滑融合。
#     物理对应：液体表面张力驱动的融合速率。
@onready var merge_rate_slider: HSlider = $VBoxContainer/Shape/MergeRate/HSlider

# ---------------------------------------------------------------------------
# @onready - 阴影组 (Shadow) 控件
# ---------------------------------------------------------------------------

# shadow_expand_slider (HSlider)
#     阴影扩展：控制阴影从形状边缘向外扩展的距离（像素）。
#     值越大，阴影越宽/越大。
@onready var shadow_expand_slider: HSlider = $VBoxContainer/Shadow/ShadowExpand/HSlider

# shadow_factor_slider (HSlider)
#     阴影强度：控制阴影的不透明度。
#     0.0 → 无阴影；1.0 → 最暗阴影。
@onready var shadow_factor_slider: HSlider = $VBoxContainer/Shadow/ShadowFactor/HSlider

# shadow_position_x_slider (HSlider)
#     阴影水平偏移：控制阴影在 X 轴方向上的偏移量（像素）。
#     正值 → 阴影向右偏移；负值 → 阴影向左偏移。
@onready var shadow_position_x_slider: HSlider = $VBoxContainer/Shadow/ShadowPositionX/HSlider

# shadow_position_y_slider (HSlider)
#     阴影垂直偏移：控制阴影在 Y 轴方向上的偏移量（像素）。
#     正值 → 阴影向下偏移；负值 → 阴影向上偏移。
#     默认 -10 → 阴影位于上方（模拟顶部光源）。
@onready var shadow_position_y_slider: HSlider = $VBoxContainer/Shadow/ShadowPositionY/HSlider

# ---------------------------------------------------------------------------
# @onready - 背景组 (Background) 控件
# ---------------------------------------------------------------------------

# bg_type_combo (OptionButton)
#     背景类型下拉菜单：
#     0 - 棋盘格：经典透明背景指示器，便于查看玻璃透明度。
#     1 - 分块：大色块背景，用于测试大范围折射偏移。
#     2 - 渐变：平滑渐变色背景，展示折射的连续变化。
#     3 - 透明：纯透明背景（配合鼠标穿透功能使用）。
@onready var bg_type_combo: OptionButton = $VBoxContainer/Background/BgType/OptionButton

# ============================================================================
# 方法：_ready()
# ============================================================================
# 参数：无
# 返回值：无
#
# 核心逻辑：
#     1. 初始化背景类型下拉菜单的选项（棋盘格、分块、渐变、透明）。
#     2. 从渲染器读取所有当前参数值，同步到对应的 UI 控件。
#        这一步确保控制面板的显示与渲染器的实际状态一致。
#
# 数值反向映射说明：
#     渲染器中的某些值在 [0.0, 1.0] 范围，而滑块 UI 使用 [0, 100] 的整数范围。
#     读取时需 `* 100.0` 还原为滑块的取值空间。
# ============================================================================
func _ready():
	bg_type_combo.clear()
	bg_type_combo.add_item("棋盘格")
	bg_type_combo.add_item("分块")
	bg_type_combo.add_item("渐变")
	bg_type_combo.add_item("透明")

	if renderer:
		ref_thickness_slider.value = renderer.ref_thickness
		ref_factor_slider.value = renderer.ref_factor
		ref_dispersion_slider.value = renderer.ref_dispersion
		ref_fresnel_range_slider.value = renderer.ref_fresnel_range
		ref_fresnel_hardness_slider.value = renderer.ref_fresnel_hardness * 100
		ref_fresnel_factor_slider.value = renderer.ref_fresnel_factor * 100

		glare_range_slider.value = renderer.glare_range
		glare_hardness_slider.value = renderer.glare_hardness * 100
		glare_factor_slider.value = renderer.glare_factor * 100
		glare_convergence_slider.value = renderer.glare_convergence * 100
		glare_opposite_factor_slider.value = renderer.glare_opposite_factor * 100
		glare_angle_slider.value = renderer.glare_angle

		blur_radius_slider.value = renderer.blur_radius
		blur_edge_check.button_pressed = renderer.blur_edge

		tint_color_picker.color = renderer.tint
		tint_alpha_slider.value = renderer.tint_alpha * 100

		merge_rate_slider.value = renderer.merge_rate * 100

		shadow_expand_slider.value = renderer.shadow_expand
		shadow_factor_slider.value = renderer.shadow_factor * 100
		shadow_position_x_slider.value = renderer.shadow_position.x
		shadow_position_y_slider.value = renderer.shadow_position.y

		bg_type_combo.selected = renderer.bg_type

# ---------------------------------------------------------------------------
# 信号处理方法 - 折射参数（Refraction）
# ---------------------------------------------------------------------------
# 以下每个方法的结构完全一致：
#   1. 检查 renderer 是否存在（容错）。
#   2. 将 UI 控件的值写入渲染器的对应属性。
#   3. 调用 renderer.update_all_uniforms() 将变更推送到 GPU 着色器。
#
# 为什么不每个属性单独更新？
#   批量更新（update_all_uniforms()）比逐个更新更高效，因为：
#   - 减少了 CPU ↔ GPU 的同步次数。
#   - 避免多个 uniform 设置导致的着色器重编译。
#   - 只需一次统一打包，减少 GDScript 调用开销。
# ---------------------------------------------------------------------------

func _on_ref_thickness_changed(value: float):
	if renderer:
		renderer.ref_thickness = value
		renderer.update_all_uniforms()

func _on_ref_factor_changed(value: float):
	if renderer:
		renderer.ref_factor = value
		renderer.update_all_uniforms()

func _on_ref_dispersion_changed(value: float):
	if renderer:
		renderer.ref_dispersion = value
		renderer.update_all_uniforms()

func _on_ref_fresnel_range_changed(value: float):
	if renderer:
		renderer.ref_fresnel_range = value
		renderer.update_all_uniforms()

func _on_ref_fresnel_hardness_changed(value: float):
	if renderer:
		renderer.ref_fresnel_hardness = value / 100.0
		renderer.update_all_uniforms()

func _on_ref_fresnel_factor_changed(value: float):
	if renderer:
		renderer.ref_fresnel_factor = value / 100.0
		renderer.update_all_uniforms()

# ---------------------------------------------------------------------------
# 信号处理方法 - 高光参数（Glare）
# ---------------------------------------------------------------------------

func _on_glare_range_changed(value: float):
	if renderer:
		renderer.glare_range = value
		renderer.update_all_uniforms()

func _on_glare_hardness_changed(value: float):
	if renderer:
		renderer.glare_hardness = value / 100.0
		renderer.update_all_uniforms()

func _on_glare_factor_changed(value: float):
	if renderer:
		renderer.glare_factor = value / 100.0
		renderer.update_all_uniforms()

func _on_glare_convergence_changed(value: float):
	if renderer:
		renderer.glare_convergence = value / 100.0
		renderer.update_all_uniforms()

func _on_glare_opposite_factor_changed(value: float):
	if renderer:
		renderer.glare_opposite_factor = value / 100.0
		renderer.update_all_uniforms()

func _on_glare_angle_changed(value: float):
	if renderer:
		renderer.glare_angle = value
		renderer.update_all_uniforms()

# ---------------------------------------------------------------------------
# 信号处理方法 - 模糊参数（Blur）
# ---------------------------------------------------------------------------

func _on_blur_radius_changed(value: float):
	if renderer:
		renderer.blur_radius = value
		renderer.update_all_uniforms()

func _on_blur_edge_toggled(value: bool):
	if renderer:
		renderer.blur_edge = value
		renderer.update_all_uniforms()

# ---------------------------------------------------------------------------
# 信号处理方法 - 色调参数（Tint）
# ---------------------------------------------------------------------------

func _on_tint_color_changed(value: Color):
	if renderer:
		renderer.tint = value
		renderer.update_all_uniforms()

func _on_tint_alpha_changed(value: float):
	if renderer:
		renderer.tint_alpha = value / 100.0
		renderer.update_all_uniforms()

# ---------------------------------------------------------------------------
# 信号处理方法 - 形状参数（Shape）
# ---------------------------------------------------------------------------

func _on_merge_rate_changed(value: float):
	if renderer:
		renderer.merge_rate = value / 100.0
		renderer.update_all_uniforms()

# ---------------------------------------------------------------------------
# 信号处理方法 - 阴影参数（Shadow）
# ---------------------------------------------------------------------------

func _on_shadow_expand_changed(value: float):
	if renderer:
		renderer.shadow_expand = value
		renderer.update_all_uniforms()

func _on_shadow_factor_changed(value: float):
	if renderer:
		renderer.shadow_factor = value / 100.0
		renderer.update_all_uniforms()

func _on_shadow_position_x_changed(value: float):
	if renderer:
		renderer.shadow_position.x = value
		renderer.update_all_uniforms()

func _on_shadow_position_y_changed(value: float):
	if renderer:
		renderer.shadow_position.y = value
		renderer.update_all_uniforms()

# ---------------------------------------------------------------------------
# 信号处理方法 - 背景参数（Background）
# ---------------------------------------------------------------------------

func _on_bg_type_changed(index: int):
	if renderer:
		renderer.bg_type = index
		renderer.update_all_uniforms()