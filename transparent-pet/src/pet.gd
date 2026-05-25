# =============================================================================
# pet.gd - 桌宠主控制器（Pet Main Controller）
# =============================================================================
#
# 【文件概述】
#   本文件是整个桌宠应用的核心控制器，挂载于主场景的根节点（Node2D）。
#   它负责协调所有子系统的初始化与运行，是整个程序的"大脑"。
#
# 【架构说明】
#   本控制器采用组合模式，将不同职责委托给专门的子系统：
#   ┌──────────────────────────────────────────────────────┐
#   │  pet.gd (主控制器)                                    │
#   │  ├── slime_1_sprite       (Sprite2D) 普通史莱姆精灵   │
#   │  ├── slime_2_sprite       (Sprite2D) 液态玻璃史莱姆   │
#   │  ├── liquid_glass_renderer (Node2D)  液态玻璃渲染器   │
#   │  ├── drag_controller      (拖拽控制)                  │
#   │  ├── mouse_manager        (鼠标交互管理)              │
#   │  ├── passthrough_manager  (鼠标穿透管理)              │
#   │  ├── material_manager     (材质/外观管理)              │
#   │  ├── vector_renderer      (矢量渲染器)                │
#   │  ├── tray_manager         (系统托盘管理)              │
#   │  └── config               (配置管理)                  │
#   └──────────────────────────────────────────────────────┘
#
# 【节点依赖关系】
#   本脚本依赖以下场景节点（必须在 .tscn 中预先定义）：
#   - Slime1:                第一个史莱姆的 Sprite2D 节点（普通史莱姆）
#   - LiquidGlassRenderer:   液态玻璃效果的父节点（Node2D）
#     └── Slime2:            第二个史莱姆的 Sprite2D 节点（玻璃效果史莱姆）
#
# 【信号流向】
#   - 用户点击 → mouse_manager → drag_controller → 移动精灵
#   - 用户拖拽 → _register_draggables → _bring_to_front → 调整 Z 层级
#   - 托盘菜单 → tray_manager → _on_tray_settings_requested / _on_tray_exit_requested
#   - 快捷键 OpenSettings → _input → open_settings_window
#
# 【重要约定】
#   - 所有 global_position 操作均以屏幕坐标系为准
#   - DPR (Device Pixel Ratio) 用于高 DPI 屏幕的物理像素计算
#   - Z 索引规则：数值越大越靠前，当前拖拽目标设为 z_index=1
# =============================================================================

extends Node2D

# -----------------------------------------------------------------------------
# 预加载依赖类（Preloaded Dependencies）
# -----------------------------------------------------------------------------
# 使用 preload 在编译时加载，避免运行时文件查找的开销。
# 每个类负责一个独立子系统的逻辑。
# -----------------------------------------------------------------------------

# 配置管理器：管理宠物的所有可配置参数（缩放、位置、材质预设等）
@onready var config = preload("res://src/pet_config.gd").new()

# 拖拽控制器：处理鼠标拖拽精灵的物理逻辑（位移计算、边界限制等）
@onready var drag_controller = preload("res://src/drag_controller.gd").new()

# 鼠标穿透管理器：控制窗体在非精灵区域的鼠标穿透行为（让点击穿透到桌面）
@onready var passthrough_manager = preload("res://addons/mouse_passthrough/mouse_passthrough.gd").new()

# 鼠标交互管理器：统一管理鼠标进入/离开/点击精灵的事件分发
@onready var mouse_manager = preload("res://src/mouse_manager.gd").new()

# 材质管理器：管理精灵的外观材质预设（颜色、光泽、透明度等视觉属性）
@onready var material_manager: MaterialManager = MaterialManager.new()

# 矢量渲染器：将 SVG 矢量图渲染为精灵纹理，支持无损缩放
@onready var vector_renderer = preload("res://src/vector_renderer.gd").new()

# 系统托盘管理器：在 Windows 系统托盘中创建图标和右键菜单
@onready var tray_manager: Node = null

# =============================================================================
# @onready 成员变量（场景节点引用）
# =============================================================================
# 这些变量使用 @onready 延迟初始化，确保在 _ready() 执行前场景树已完全构建。
# 使用 @onready 而非在 _ready() 中赋值，可以让依赖顺序自动处理，
# Godot 会按照声明顺序从上到下初始化这些变量。
# =============================================================================

# 普通史莱姆精灵节点（Slime1）
# 类型: Sprite2D
# 用途: 显示第一个（普通）史莱姆的外观，是主要的交互目标
# 场景路径: 根节点/Slime1
@onready var slime_1_sprite: Sprite2D = $Slime1

# 液态玻璃史莱姆精灵节点（Slime2）
# 类型: Sprite2D
# 用途: 显示第二个（玻璃效果）史莱姆的外观，渲染为半透明液态玻璃材质
# 场景路径: 根节点/LiquidGlassRenderer/Slime2
@onready var slime_2_sprite: Sprite2D = $LiquidGlassRenderer/Slime2

# 液态玻璃渲染器节点
# 类型: Node2D
# 用途: 控制液态玻璃特效的渲染参数（模糊、着色、形状等）
#       通过 shader 实现类似水滴/玻璃的折射与模糊视觉效果
# 场景路径: 根节点/LiquidGlassRenderer
@onready var liquid_glass_renderer: Node2D = $LiquidGlassRenderer

# 当前激活的玻璃项实例
# 存储 _setup_liquid_glass_slime() 中创建的 GlassItem 对象引用
# 用于在 _process() 每帧更新其屏幕位置
var glass_item: GlassItem = null

# =============================================================================
# 可拖拽物体列表（Draggable List）
# =============================================================================
# 存储所有可以被鼠标拖拽的物体信息。
# 每个元素是一个字典：
#   {
#     "sprite": Sprite2D，  用于鼠标碰撞检测的精灵
#     "id":     String，    唯一标识符，用于 Z 层级排序
#     "render": Node2D，   需要调整 z_index 的渲染节点
#   }
# 列表按 z_index 降序排列，最前面的元素最先被检测。
# =============================================================================
var draggable_list: Array = []

# SVG 资源路径常量
# 存储矢量精灵图的文件路径，用于 vector_renderer 加载和渲染
const SVG_PATH: String = "res://assets/icons/pet_sprite.svg"

# =============================================================================
# _ready() - 初始化回调
# =============================================================================
# 触发时机: 节点进入场景树后，所有子节点就绪时，由 Godot 引擎自动调用。
# 这是整个桌宠程序的启动入口，负责按顺序初始化所有子系统。
#
# 初始化顺序经过精心设计：
#   1. 先开启输入处理 → 确保不会遗漏用户输入
#   2. 渲染精灵 → 外观先行，用户立即看到桌宠
#   3. 初始化材质 → 依赖精灵已渲染
#   4. 居中定位 → 依赖精灵已存在
#   5. 同步双精灵位置 → 两个史莱姆初始位置一致
#   6. 初始化交互系统 → 依赖精灵已就位
#   7. 创建托盘 → 依赖主控制器已就绪
#   8. 设置玻璃特效 → 依赖渲染器已初始化
#   9. 注册可拖拽物体 → 所有精灵已就位
# =============================================================================
func _ready():
	print("✅ [桌宠] ====== 桌宠主程序初始化完成 ========")

	# 启用输入处理，让 _input() 能接收全局输入事件（如快捷键）
	set_process_input(true)

	# 使用矢量渲染器将 SVG 渲染到 slime_1_sprite 上
	# 矢量渲染的优势：任意缩放不失真，适合 DPI 变化的场景
	vector_renderer.init(slime_1_sprite, SVG_PATH)

	# 初始化材质管理器，将材质应用到 slime_1_sprite
	material_manager.init(slime_1_sprite)

	# 根据配置预设应用材质外观（颜色方案等）
	init_materials()

	# 将精灵居中放置到屏幕中央或配置文件指定的初始位置
	center_sprite()

	# 让 slime_2_sprite（玻璃效果）初始位置与 slime_1_sprite（普通）完全重叠
	# 这样两个史莱姆在视觉上从同一位置开始
	slime_2_sprite.global_position = slime_1_sprite.global_position

	# 初始化拖拽控制器
	# 传入 self（当前 Node2D），让 drag_controller 可以访问全局坐标系统
	drag_controller.init(self)

	# 初始化鼠标穿透管理器
	# 让窗口在非精灵区域对鼠标透明（点击穿透到桌面应用）
	passthrough_manager.init(self)

	# 初始化鼠标交互管理器
	# 绑定 slime_1_sprite 和穿透管理器，处理鼠标与精灵的交互
	mouse_manager.init(self, slime_1_sprite, passthrough_manager)

	# 将 slime_2_sprite 注册到鼠标管理器
	# 使得玻璃效果史莱姆也能响应鼠标交互
	mouse_manager.set_slime_2_sprite(slime_2_sprite)

	# 延迟创建托盘管理器并添加到场景树
	# 使用 preload 避免循环依赖，在运行时动态加载
	tray_manager = preload("res://src/tray_manager.gd").new()
	add_child(tray_manager)
	tray_manager.init(self)

	# 连接托盘菜单信号
	# 当用户点击"设置"时触发 → 打开设置窗口
	tray_manager.settings_requested.connect(_on_tray_settings_requested)
	# 当用户点击"退出"时触发 → 关闭整个应用
	tray_manager.exit_requested.connect(_on_tray_exit_requested)

	# 打印当前配置到控制台，方便调试
	config.print_config()

	# 组装液态玻璃史莱姆特效（创建 GlassItem + 渲染参数）
	_setup_liquid_glass_slime()

	# 注册所有可拖拽物体到碰撞检测链
	# 必须在所有精灵和渲染器初始化之后调用
	_register_draggables()

# =============================================================================
# _on_tray_settings_requested() - 托盘"设置"信号回调
# =============================================================================
# 触发时机: 用户在系统托盘右键菜单中点击"设置"选项
# 参数: 无
# 返回值: 无
# 行为: 调用 open_settings_window() 打开宠物配置窗口
# =============================================================================
func _on_tray_settings_requested():
	open_settings_window()

# =============================================================================
# _on_tray_exit_requested() - 托盘"退出"信号回调
# =============================================================================
# 触发时机: 用户在系统托盘右键菜单中点击"退出"选项
# 参数: 无
# 返回值: 无
# 行为: 调用 get_tree().quit() 优雅地关闭整个 Godot 应用程序
#       这会触发所有节点的 _exit_tree() 清理逻辑
# =============================================================================
func _on_tray_exit_requested():
	get_tree().quit()

# =============================================================================
# init_materials() - 初始化精灵材质
# =============================================================================
# 参数: 无
# 返回值: 无
# 核心逻辑:
#   1. 从配置中读取当前选中的材质预设 ID
#   2. 通过 material_manager 查找对应的预设
#   3. 如果找到则应用；如果找不到则回退到 "slime_1" 默认预设
#   这种回退机制确保即使配置文件损坏，桌宠也能以默认外观启动
# =============================================================================
func init_materials():
	var preset_id = config.material_preset
	var preset = material_manager.get_preset_by_id(preset_id)
	if preset:
		material_manager.apply_preset(preset)
	else:
		# 回退机制：当前预设无效时使用默认的蓝色史莱姆外观
		# 这是一个安全网，防止因配置错误导致精灵不可见
		var fallback = material_manager.get_preset_by_id("slime_1")
		material_manager.apply_preset(fallback)

# =============================================================================
# center_sprite() - 将普通史莱姆精灵居中放置
# =============================================================================
# 参数: 无
# 返回值: 无
# 核心逻辑:
#   1. 获取当前显示器的分辨率作为默认居中目标
#   2. 如果配置文件指定了初始坐标(window_initial_x/y >= 0)，则使用配置坐标
#   3. 将 slime_1_sprite 移动到目标位置（global_position）
#   4. 应用配置中的缩放比例
# 设计决策:
#   - 使用 global_position 而非 position，确保跨窗口坐标一致
#   - 坐标值为 -1 表示"未设置"，此时使用屏幕中央作为默认值
# =============================================================================
func center_sprite():
	if slime_1_sprite:
		# 获取主显示器分辨率（物理像素）
		# DisplayServer.screen_get_size() 返回 Vector2i，不含 DPI 缩放
		var screen_size_i: Vector2i = DisplayServer.screen_get_size()
		var screen_size: Vector2 = Vector2(screen_size_i.x, screen_size_i.y)

		# 默认居中：屏幕宽高各取一半
		var target_x: float = screen_size.x / 2
		var target_y: float = screen_size.y / 2

		# 如果配置中指定了初始坐标（值 >= 0 表示有效坐标），则覆盖默认值
		if config.window_initial_x >= 0:
			target_x = config.window_initial_x
		if config.window_initial_y >= 0:
			target_y = config.window_initial_y

		# 设置精灵全局位置
		slime_1_sprite.global_position = Vector2(target_x, target_y)

		# 应用初始缩放比例
		update_pet_scale(config.pet_scale)

		print("[精灵] 精灵全局位置：", slime_1_sprite.global_position)
		print("[精灵] 精灵缩放大小：", config.pet_scale)

# =============================================================================
# get_current_material_name() - 获取当前材质名称
# =============================================================================
# 参数: 无
# 返回值: String - 当前激活的材质预设名称
# 用途: 供外部（如设置窗口）查询当前使用的外观主题
# =============================================================================
func get_current_material_name() -> String:
	return material_manager.get_current_material_name()

# =============================================================================
# _process(delta) - 每帧更新回调
# =============================================================================
# 触发时机: Godot 引擎每帧自动调用，频率取决于显示器刷新率
# 参数:
#   _delta: float - 自上一帧以来的时间间隔（秒），前缀下划线表示未使用
# 核心逻辑:
#   1. 更新拖拽状态（如果正在拖拽，平滑跟随鼠标）
#   2. 同步玻璃项位置到 slime_2_sprite（考虑 DPI 缩放）
#   3. 更新鼠标穿透区域（响应精灵移动）
# 注意: 玻璃项使用物理像素坐标，所以需要乘以 DPR
# =============================================================================
func _process(_delta: float):
	# 拖拽更新：如果当前有精灵正在被拖拽，drag_controller 会更新其位置
	drag_controller.update_drag()

	# 同步玻璃特效项的位置
	# glass_item 使用物理像素坐标（用于 shader 渲染），
	# slime_2_sprite.global_position 是逻辑坐标，
	# 需要通过 content_scale_factor (DPR) 转换
	if glass_item:
		var dpr: float = get_tree().root.content_scale_factor
		glass_item.position = slime_2_sprite.global_position * dpr
		# 通知渲染器重新计算 uniform 参数，使 shader 中的位置信息保持最新
		liquid_glass_renderer.update_items_uniforms()

	# 更新鼠标穿透区域，确保精灵移动后穿透区域正确跟随
	mouse_manager.update_mouse_passthrough()

# =============================================================================
# _register_draggables() - 注册可拖拽物体列表
# =============================================================================
# 参数: 无
# 返回值: 无
# 核心逻辑:
#   1. 将两个史莱姆精灵注册到 draggable_list
#   2. 按 z_index 降序排列（z_index 大的在前面，优先被检测）
# 设计原因:
#   - 使用独立列表管理可拖拽物体，而非硬编码两个精灵，
#     便于未来扩展更多可交互元素
#   - 排序确保在上层的精灵先响应点击事件
#   - "render" 字段指向需要调整 z_index 的节点：
#     slime_1_sprite 直接调整自身，
#     liquid_glass_renderer 作为容器调整整个玻璃效果组
# =============================================================================
func _register_draggables():
	draggable_list.append({"sprite": slime_1_sprite, "id": "slime_1", "render": slime_1_sprite})
	draggable_list.append({"sprite": slime_2_sprite, "id": "slime_2", "render": liquid_glass_renderer})
	# 按 z_index 降序排列：z_index 越大越靠前，优先参与碰撞检测
	draggable_list.sort_custom(func(a, b): return a.sprite.z_index > b.sprite.z_index)
	print("✅ [碰撞链] 已注册 %d 个可拖拽物体" % draggable_list.size())

# =============================================================================
# _on_draggable_input_event() - 可拖拽物体输入事件回调
# =============================================================================
# 触发时机: 当用户在可拖拽物体上产生鼠标输入时（由 Area2D 信号触发）
# 参数:
#   _viewport: Node  - 产生事件的视口（未使用）
#   event: InputEvent - 输入事件对象
#   _shape_idx: int  - 碰撞形状索引（未使用）
# 核心逻辑:
#   - 鼠标按下时:
#       遍历 draggable_list（按 z_index 排序），找到鼠标所在的精灵，
#       将其提升到最前（z_index=1），并开始拖拽
#   - 鼠标释放时:
#       结束拖拽（传入 null 表示无拖拽目标）
# 设计原因:
#   - 遍历排序后的列表确保上层精灵优先响应
#   - _bring_to_front 让被点击的精灵视觉上浮到最上层
# =============================================================================
func _on_draggable_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	# 只处理鼠标按钮事件，忽略键盘、手柄等其他输入
	if not (event is InputEventMouseButton):
		return

	if event.pressed:
		# 鼠标按下：查找被点击的精灵
		for entry in draggable_list:
			if _mouse_in_sprite(entry.sprite):
				# 将被点击的精灵提升到最前面
				_bring_to_front(entry.id)
				# 开始拖拽该精灵
				drag_controller.handle_area_input_event(event, entry.sprite)
				return
	else:
		# 鼠标释放：停止拖拽，传入 null 表示无拖拽目标
		drag_controller.handle_area_input_event(event, null)

# =============================================================================
# _bring_to_front(target_id) - 将指定精灵提升到最前面
# =============================================================================
# 参数:
#   target_id: String - 要置顶的精灵 ID（"slime_1" 或 "slime_2"）
# 返回值: 无
# 核心逻辑:
#   1. 遍历所有可拖拽物体，将目标设为 z_index=1，其余设为 z_index=0
#   2. 重新排序 draggable_list 以反映新的 z_index 顺序
# 设计原因:
#   - z_index=1 的节点渲染在所有 z_index=0 节点之上
#   - 重新排序列表确保后续的碰撞检测从最上层开始
# =============================================================================
func _bring_to_front(target_id: String):
	for entry in draggable_list:
		entry.render.z_index = 1 if entry.id == target_id else 0
	# 重新排序以保持碰撞检测顺序与渲染顺序一致
	draggable_list.sort_custom(func(a, b): return a.sprite.z_index > b.sprite.z_index)

# =============================================================================
# _mouse_in_sprite(sprite) - 检测鼠标是否在精灵的可见区域内
# =============================================================================
# 参数:
#   sprite: Sprite2D - 要检测的精灵节点
# 返回值:
#   bool - true 表示鼠标指针在精灵的可见像素上
# 核心逻辑:
#   1. 检查精灵是否有纹理（无纹理则不可能命中）
#   2. 用全局坐标的矩形做快速粗检测（排除明显不在的情况）
#   3. 将鼠标坐标转换为精灵本地坐标
#   4. 读取纹理对应像素的 alpha 值，仅当 alpha > 0 时返回 true
# 设计原因:
#   - 像素级检测解决矩形碰撞不精确的问题（精灵通常有透明边缘）
#   - 先做矩形粗检测是为了性能：大部分情况下矩形检测即可排除
#   - 用 get_image() 读取纹理像素是像素级碰撞的标准做法
# =============================================================================
func _mouse_in_sprite(sprite: Sprite2D) -> bool:
	# 精灵没有纹理，无法进行像素检测
	if not sprite.texture:
		return false

	var mouse_pos = get_global_mouse_position()

	# 第一阶段：矩形包围盒粗检测（性能优化）
	# 用精灵的全局矩形框快速排除明显不在范围内的鼠标位置
	var rect = sprite.get_rect()
	var global_rect = Rect2(sprite.global_position - rect.size / 2, rect.size)
	if not global_rect.has_point(mouse_pos):
		return false

	# 第二阶段：像素级精确检测
	# 将全局鼠标坐标转换为精灵的本地纹理坐标
	var local_pos = sprite.to_local(mouse_pos)
	var tex_size = sprite.texture.get_size() * sprite.scale

	# 计算像素索引（从左上角为原点）
	var px = int(local_pos.x + tex_size.x / 2)
	var py = int(local_pos.y + tex_size.y / 2)

	# 边界检查：防止越界访问
	if px < 0 or px >= tex_size.x or py < 0 or py >= tex_size.y:
		return false

	# 读取像素 alpha 通道：alpha > 0 表示该像素可见（非透明）
	var img = sprite.texture.get_image()
	return img.get_pixel(px, py).a > 0

# =============================================================================
# _input(event) - 全局输入事件回调
# =============================================================================
# 触发时机: 在任何 GUI 元素处理输入之前，由 Godot 引擎调用
# 参数:
#   event: InputEvent - 输入事件对象
# 核心逻辑:
#   1. 检测鼠标左键释放 → 通知 drag_controller 停止拖拽
#   2. 检测快捷键 "OpenSettings" → 打开设置窗口
# 设计原因:
#   - 左键释放放在 _input 而非 _on_draggable_input_event，
#     因为释放可能发生在精灵区域之外（用户拖出精灵后松手）
#   - 快捷键使用 Input Map 中定义的 "OpenSettings" action，
#     方便用户在项目设置中自定义键位
# =============================================================================
func _input(event: InputEvent):
	# 鼠标左键释放时终止拖拽
	# 必须在这里处理，因为松开位置可能不在任何 Area2D 上
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		drag_controller.handle_area_input_event(event, null)

	# 快捷键打开设置：由 Input Map 中的 "OpenSettings" action 定义
	if event.is_action_pressed("OpenSettings"):
		open_settings_window()

# =============================================================================
# open_settings_window() - 打开设置窗口
# =============================================================================
# 参数: 无
# 返回值: 无
# 核心逻辑:
#   1. 动态加载设置窗口场景
#   2. 实例化并添加到根视口
#   3. 将当前主控制器传递给它（让设置窗口能修改配置）
#   4. 将窗口定位在精灵右侧偏上（避免遮挡桌宠）
# 设计原因:
#   - 使用 load + instantiate 而非预加载，避免启动时占用内存
#   - 定位偏移量 (50, -130) 经过视觉调优，让窗口出现在合适位置
#   - 通过 set_pet_node(self) 注入依赖，遵循依赖注入模式
# =============================================================================
func open_settings_window():
	var settings_scene = load("res://scenes/settings_window.tscn")
	if settings_scene:
		var settings_window = settings_scene.instantiate()
		get_tree().root.add_child(settings_window)

		# 依赖注入：将主控制器引用传递给设置窗口
		settings_window.set_pet_node(self)

		# 窗口定位：以精灵位置为基准，向右偏移 50px，向上偏移 130px
		var pet_pos = slime_1_sprite.global_position
		var settings_pos = Vector2(pet_pos.x + 50, pet_pos.y - 130)
		settings_window.position = settings_pos

# =============================================================================
# update_pet_scale(new_scale) - 更新宠物缩放比例
# =============================================================================
# 参数:
#   new_scale: float - 新的缩放比例（1.0 = 原始大小）
# 返回值: 无
# 用途: 供设置窗口等外部调用，改变宠物的显示大小
# =============================================================================
func update_pet_scale(new_scale: float):
	vector_renderer.update_scale(new_scale)

# =============================================================================
# apply_high_res_scale(new_scale) - 应用高分辨率缩放
# =============================================================================
# 参数:
#   new_scale: float - 新的高分辨率缩放比例
# 返回值: 无
# 用途: 处理高 DPI 显示器下的特殊缩放需求
# =============================================================================
func apply_high_res_scale(new_scale: float):
	vector_renderer.apply_high_res_scale(new_scale)

# =============================================================================
# set_always_on_top(enabled) - 设置窗口置顶属性
# =============================================================================
# 参数:
#   enabled: bool - true 表示窗口始终保持在最前
# 返回值: 无
# 用途: 控制桌宠窗口是否始终显示在其他窗口之上
# =============================================================================
func set_always_on_top(enabled: bool):
	if owner:
		owner.get_window().always_on_top = enabled

# =============================================================================
# get_window_size() - 获取当前窗口尺寸
# =============================================================================
# 参数: 无
# 返回值: Vector2i - 窗口的宽度和高度（像素），无 owner 时返回零向量
# =============================================================================
func get_window_size() -> Vector2i:
	return owner.get_window().size if owner else Vector2i.ZERO

# =============================================================================
# get_window_position() - 获取当前窗口位置
# =============================================================================
# 参数: 无
# 返回值: Vector2i - 窗口左上角在屏幕上的坐标，无 owner 时返回零向量
# =============================================================================
func get_window_position() -> Vector2i:
	return owner.get_window().position if owner else Vector2i.ZERO

# =============================================================================
# _setup_liquid_glass_slime() - 组装液态玻璃史莱姆特效
# =============================================================================
# 参数: 无
# 返回值: 无
# 核心逻辑:
#   1. 配置液态玻璃渲染器的视觉参数（模糊、着色等）
#   2. 创建一个史莱姆形状的 GlassItem 并添加到渲染器
#   3. 将 GlassItem 位置同步到 slime_2_sprite
# 设计原因:
#   - 液态玻璃效果通过 shader 实现模拟水滴/玻璃的折射和模糊
#   - bg_type=3 选择史莱姆形状的背景模式
#   - 着色使用半透明蓝色 (0.3, 0.6, 0.9, 0.35) 营造玻璃质感
#   - GlassItem 使用物理像素坐标（乘以 DPR），与 shader 坐标系统一致
# =============================================================================
func _setup_liquid_glass_slime():
	# 安全守卫：确保渲染器节点存在
	if not liquid_glass_renderer:
		return

	# 安全守卫：确保普通史莱姆精灵存在
	if not slime_1_sprite:
		return

	# 配置渲染器背景类型：3 = 史莱姆形状背景
	liquid_glass_renderer.bg_type = 3
	# 启用边缘模糊效果，让玻璃看起来更自然
	liquid_glass_renderer.blur_edge = true
	# 模糊半径：2.0 像素，提供柔和的边缘过渡
	liquid_glass_renderer.blur_radius = 2.0

	# 配置玻璃着色颜色：柔和的蓝色调
	# R=0.3, G=0.6, B=0.9 产生类似水滴的淡蓝色
	var glass_color = Color(0.3, 0.6, 0.9, 1.0)
	liquid_glass_renderer.tint = glass_color
	# 着色透明度：0.35 让玻璃效果半透明，可以看到背景
	liquid_glass_renderer.tint_alpha = 0.35

	# 获取渲染器内部的项目管理器并清空旧数据
	var item_manager = liquid_glass_renderer.get_item_manager()
	item_manager.clear_all()

	# 获取设备像素比，用于将逻辑坐标转换为物理像素坐标
	var dpr: float = get_tree().root.content_scale_factor
	var pos = slime_2_sprite.global_position * dpr

	# 创建史莱姆形状的玻璃项
	var slime_item = GlassItem.new()
	# 形状类型：SLIME = 类似水滴/史莱姆的有机形状
	slime_item.shape_type = GlassItem.ShapeType.SLIME
	# 初始位置：与 slime_2_sprite 重叠（物理像素坐标）
	slime_item.position = pos
	# 玻璃项的宽高尺寸
	slime_item.width = 200.0
	slime_item.height = 132.0
	# 圆角半径：控制形状的圆润程度
	slime_item.radius = 65.0
	# 缩放：与宠物配置保持一致
	slime_item.scale = config.pet_scale
	# 启用渲染
	slime_item.enabled = true

	# 将玻璃项添加到渲染器
	item_manager.add_item(slime_item)

	# 保存引用，供 _process() 中每帧更新位置
	glass_item = slime_item

	# 立即刷新 shader 参数
	liquid_glass_renderer.update_items_uniforms()
	liquid_glass_renderer.update_all_uniforms()

	print("✅ [液态玻璃] 已创建，跟1号史莱姆(普通)位置同步")
