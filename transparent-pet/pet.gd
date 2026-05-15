##
# 桌宠主控制器脚本
# 负责管理桌宠的核心功能，包括材质系统、窗口控制、拖拽交互和鼠标穿透
##
extends Node2D

# 配置管理器实例，用于加载和保存桌宠配置
@onready var config = preload("res://config/PetConfig.gd").new()
# 拖拽控制脚本，处理桌宠的拖拽移动功能
@onready var drag_script = preload("res://pet_drag.gd").new()
# 鼠标穿透管理器，控制鼠标事件的穿透行为
@onready var passthrough_manager = preload("res://addons/mouse_passthrough/mouse_passthrough.gd").new()
# 鼠标交互管理器，处理鼠标悬停和交互逻辑
@onready var mouse_manager = preload("res://pet_mouse_manager.gd").new()
# 材质管理器，负责材质加载和应用
@onready var material_manager = preload("res://pet_material_manager.gd").new()
# 桌宠精灵节点引用，用于渲染桌宠图像
@onready var pet_sprite: Sprite2D = $Sprite2D

# 当前使用的材质ID (1-4对应四种预设材质)
var current_material_id: int = 1

##
# 节点初始化完成回调函数
# 执行桌宠的完整初始化流程
##
func _ready():
	print("✅ [桌宠] ====== 桌宠主程序初始化完成 ========")
	config.print_config()
	
	init_materials()
	init_window()
	center_sprite()
	
	drag_script.init(self)
	passthrough_manager.init(self)
	mouse_manager.init(self, pet_sprite, passthrough_manager)

##
# 初始化材质系统
# 从配置加载当前材质ID并应用对应的预设
##
func init_materials():
	material_manager.init(pet_sprite)
	current_material_id = config.current_material
	var preset = config.load_preset(current_material_id)
	material_manager.apply_preset(preset, current_material_id)

##
# 初始化窗口属性
# 设置窗口置顶等配置
##
func init_window():
	var window = get_window()
	window.always_on_top = config.window_always_on_top
	
	print("📌 [窗口] 窗口尺寸：", window.size, "，位置：", window.position)
	print("📌 [窗口] 窗口属性 - 透明：", window.transparent)
	print("📌 [窗口] 窗口属性 - 置顶：", window.always_on_top)

##
# 将精灵居中显示
# 根据配置设置精灵的初始位置和缩放比例
##
func center_sprite():
	if pet_sprite:
		var screen_size_i: Vector2i = DisplayServer.screen_get_size()
		var screen_size: Vector2 = Vector2(screen_size_i.x, screen_size_i.y)
		
		var target_x: float = screen_size.x / 2
		var target_y: float = screen_size.y / 2
		
		if config.window_initial_x >= 0:
			target_x = config.window_initial_x
		if config.window_initial_y >= 0:
			target_y = config.window_initial_y
		
		pet_sprite.global_position = Vector2(target_x, target_y)
		pet_sprite.scale = Vector2(config.pet_scale, config.pet_scale)
		
		print("[精灵] 精灵全局位置：", pet_sprite.global_position)
		print("[精灵] 精灵缩放大小：", config.pet_scale)

##
# 切换材质循环
# 按顺序切换四种材质预设（液态→毛玻璃→水晶→极光→液态）
##
func toggle_material():
	current_material_id = (current_material_id % 4) + 1
	config.current_material = current_material_id
	var preset = config.load_preset(current_material_id)
	material_manager.apply_preset(preset, current_material_id)
	config.save_config()

##
# 获取当前材质名称
# @return String - 当前材质的中文名称
##
func get_current_material_name() -> String:
	return material_manager.get_current_material_name()

##
# 每帧更新回调
# 更新拖拽状态和鼠标穿透状态
# @param _delta: float - 帧时间间隔（未使用）
##
func _process(_delta):
	drag_script.update_drag()
	mouse_manager.update_mouse_passthrough()

##
# 区域输入事件处理
# 将输入事件传递给拖拽脚本处理
# @param _viewport: Node - 视口节点（未使用）
# @param event: InputEvent - 输入事件对象
# @param _shape_idx: int - 形状索引（未使用）
##
func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	drag_script.handle_area_input_event(event)
