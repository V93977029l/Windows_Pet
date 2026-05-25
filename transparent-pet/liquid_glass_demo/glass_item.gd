# ============================================================================
# 文件：glass_item.gd
# ============================================================================
# 作用：
#     本文件定义了"玻璃项目"(GlassItem) 数据类。它描述了一个可渲染的
#     液态玻璃形状的所有几何属性和状态信息。作为纯数据载体（DTO），
#     它不包含任何渲染逻辑，只负责参数的存储与序列化。
#
# 设计模式：
#     - 【数据对象模式 (DTO / Data Object)】：`GlassItem` 是一个纯粹的
#       数据结构类，不继承 Node，只存储数据并提供序列化/反序列化方法。
#       渲染逻辑完全委托给渲染器（`LiquidGlassRenderer`）和着色器。
#     - 【策略模式 (Strategy Pattern) - 枚举分发】：通过 `ShapeType` 枚举
#       定义形状类型，着色器端根据 `shape_type` 值选择对应的 SDF 计算策略。
#
# 架构说明：
#     `GlassItem` 实例由 `GlassItemManager` 统一管理，每帧由渲染器将
#     所有项目的参数批量打包为 PackedArray 后传递给 GPU 着色器。
#     `to_shader_params()` 方法负责将 GDScript 类型转换为着色器友好的
#     纯 float 类型字典（着色器不支持 enum 等高级类型）。
#
# 与着色器的交互机制：
#     着色器端接收 8 个固定长度的数组（每个数组长度为 `MAX_ITEMS`=3）：
#       - u_itemPositions[]   → Vector2（位置）
#       - u_itemWidths[]      → float （宽度）
#       - u_itemHeights[]     → float （高度）
#       - u_itemRadii[]       → float （圆角半径）
#       - u_itemRoundness[]   → float （圆滑度）
#       - u_itemShapeTypes[]  → float （形状类型枚举值）
#       - u_itemEnabled[]     → float （启用标志，0.0 或 1.0）
#       - u_itemScales[]      → float （缩放因子）
# ============================================================================

# ============================================================================
# 类：GlassItem
# ============================================================================
# 职责：
#     - 封装单个液态玻璃形状的全部几何参数。
#     - 提供序列化方法（`to_shader_params()`）将参数转换为着色器可读格式。
#     - 提供反序列化方法（`_init_from_dict()`）从字典恢复对象。
#     - 提供碰撞检测方法（`get_bounding_rect()` / `contains_point()`）。
# ============================================================================
class_name GlassItem

# ============================================================================
# 枚举：ShapeType
# ============================================================================
# 定义了当前系统支持的三种玻璃形状类型。
# 枚举值以整数传递给着色器，着色器端通过 switch-case 分发到不同的
# SDF（Signed Distance Function，有符号距离函数）计算分支。
#
# 值列表：
#     CIRCLE       (0) - 圆形/椭圆形：使用椭圆 SDF 计算。
#                        由 `radius` 控制圆角半径。
#     ROUNDED_RECT (1) - 圆角矩形：由 `width`、`height` 控制大小，
#                        `radius` 控制四角圆滑度，`roundness` 控制边框的
#                        过渡平滑度。
#     SLIME        (2) - 史莱姆（软体变形）：在圆形基础上叠加分形噪声
#                        和弹簧形变，产生蠕动的有机感效果。由鼠标位置驱动
#                        形变幅度。
# ============================================================================
enum ShapeType {
    CIRCLE = 0,
    ROUNDED_RECT = 1,
    SLIME = 2
}

# ---------------------------------------------------------------------------
# 公开属性（@export 使得这些属性可以在 Godot 编辑器中直接编辑和查看）
# ---------------------------------------------------------------------------

# position (Vector2)
#     形状在视口坐标系中的中心点位置，单位为像素。
#     默认值为原点 (0, 0)。
@export var position: Vector2 = Vector2.ZERO

# width (float)
#     形状的宽度，单位为像素。
#     对于圆形：影响椭圆的水平半径。
#     对于圆角矩形：影响矩形的宽度。
#     对于史莱姆：影响基础圆的水平拉伸。
@export var width: float = 200.0

# height (float)
#     形状的高度，单位为像素。
#     对于圆形：影响椭圆的垂直半径。
#     对于圆角矩形：影响矩形的高度。
#     对于史莱姆：影响基础圆的垂直拉伸。
@export var height: float = 200.0

# radius (float)
#     圆角半径，单位为像素。
#     对于圆形：即为圆的半径（当 width==height 时为正圆）。
#     对于圆角矩形：控制四角的圆弧半径。
#     对于史莱姆：基础圆的半径。
@export var radius: float = 80.0

# roundness (float)
#     形状边缘的柔和/平滑程度，用于圆角矩形的边框过渡效果。
#     值越大，矩形边缘越接近圆角化的平滑过渡。
#     在着色器端，此值影响 SDF 中平滑 step 函数的过渡区间宽度。
@export var roundness: float = 5.0

# shape_type (ShapeType)
#     形状类型枚举值，决定使用哪种 SDF 计算策略。
#     默认值为圆角矩形。
@export var shape_type: ShapeType = ShapeType.ROUNDED_RECT

# enabled (bool)
#     此玻璃形状是否启用（可见且参与渲染）。
#     disabled 的项在着色器端会被跳过，不会产生任何视觉效果。
@export var enabled: bool = true

# scale (float)
#     统一的缩放因子（各向同性缩放）。
#     同时影响宽度、高度和半径的最终计算。
#     默认值为 1.0（原始大小）。
@export var scale: float = 1.0

# ============================================================================
# 方法：_init()
# ============================================================================
# 默认构造函数。由于所有属性都有默认值，此处为空实现。
# 实例创建后可通过直接访问属性进行配置。
# ============================================================================
func _init():
    pass

# ============================================================================
# 方法：_init_from_dict(data: Dictionary)
# ============================================================================
# 参数：
#     data (Dictionary) - 包含属性键值对的字典。键名与属性名一致。
#                         缺失的键会被忽略，对应属性保持默认值。
#
# 返回值：无
#
# 核心逻辑：
#     遍历字典中的每个键，若该键对应类中的某个属性，则将其值赋值给该属性。
#     这是一种简单的反序列化机制，用于从保存的数据或配置文件恢复 GlassItem。
#
# 使用场景：
#     - 从 JSON 文件加载预设配置。
#     - 从网络数据包还原玻璃形状状态。
#     - 实现"撤销/重做"功能时还原快照。
# ============================================================================
func _init_from_dict(data: Dictionary):
    if data.has("position"):
        position = data.position
    if data.has("width"):
        width = data.width
    if data.has("height"):
        height = data.height
    if data.has("radius"):
        radius = data.radius
    if data.has("roundness"):
        roundness = data.roundness
    if data.has("shape_type"):
        shape_type = data.shape_type
    if data.has("enabled"):
        enabled = data.enabled
    if data.has("scale"):
        scale = data.scale

# ============================================================================
# 方法：to_shader_params() → Dictionary
# ============================================================================
# 参数：无
#
# 返回值：
#     Dictionary - 包含所有属性的字典，其中：
#         - shape_type 被转换为 float（着色器不支持 enum 类型）
#         - enabled 被转换为 1.0（启用）或 0.0（禁用）
#
# 核心逻辑：
#     将 GlassItem 的所有属性打包为一个字典，准备传递给着色器。
#     由于 Godot 着色器系统不支持字典、枚举等复杂类型，这里做了两处转换：
#       1. shape_type: enum → float(shape_type) → 着色器中以整数匹配
#       2. enabled:  bool → 1.0 / 0.0      → 着色器中的条件分支因子
#
# 与 `GlassItemManager.get_items_for_shader()` 的区别：
#     本方法将单个项目转为字典；
#     `get_items_for_shader()` 将所有项目转为 8 个 PackedArray。
# ============================================================================
func to_shader_params() -> Dictionary:
    return {
        "position": position,
        "width": width,
        "height": height,
        "radius": radius,
        "roundness": roundness,
        "shape_type": float(shape_type),
        "enabled": 1.0 if enabled else 0.0,
        "scale": scale
    }

# ============================================================================
# 方法：get_bounding_rect() → Rect2
# ============================================================================
# 参数：无
#
# 返回值：
#     Rect2 - 以形状中心为基准的包围矩形。
#             position 参数作为矩形中心，宽度和高度各乘以 scale。
#
# 核心逻辑（包围盒计算）：
#     half_width  = (width  × scale) / 2
#     half_height = (height × scale) / 2
#     bounding_rect_origin = position - (half_width, half_height)
#     bounding_rect_size   = (width × scale, height × scale)
#
# 数学原理：
#     Rect2 的定义方式为 (左上角坐标, 尺寸)。由于 position 存储的是形状
#     的中心点，因此需要减去半宽/半高来得到左上角坐标。
#     缩放因子 scale 会影响最终的包围盒大小，确保鼠标点击判定与视觉一致。
#
# 使用场景：
#     - 鼠标点击命中测试（`contains_point`）。
#     - 拖拽选择时的粗略范围判定。
#     - 视口裁剪时判断形状是否在可见区域内。
# ============================================================================
func get_bounding_rect() -> Rect2:
    var half_width = (width * scale) / 2.0
    var half_height = (height * scale) / 2.0
    return Rect2(
        position - Vector2(half_width, half_height),
        Vector2(width * scale, height * scale)
    )

# ============================================================================
# 方法：contains_point(point: Vector2) → bool
# ============================================================================
# 参数：
#     point (Vector2) - 待检测的屏幕坐标点（视口坐标系）。
#
# 返回值：
#     bool - 若 point 落在包围矩形内则返回 true，否则返回 false。
#
# 注意：
#     这是一个简化的 AABB（轴对齐包围盒）碰撞检测，不区分形状的具体轮廓。
#     对于鼠标点击选择这样的交互场景，AABB 检测已足够准确且性能优秀。
#     如需像素级精确检测（例如判断点击是否在圆角矩形内部），应考虑使用
#     SDF 反向计算（即在着色器中查询有符号距离值）。
# ============================================================================
func contains_point(point: Vector2) -> bool:
    return get_bounding_rect().has_point(point)