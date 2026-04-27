extends Node2D

# 桌宠主程序
# 功能：透明窗口、精灵居中、鼠标拖动、鼠标穿透

@onready var drag_script = preload("res://pet_drag.gd").new()
@onready var passthrough_manager = preload("res://addons/mouse_passthrough/mouse_passthrough.gd").new()
@onready var mouse_manager = preload("res://pet_mouse_manager.gd").new()
@onready var pet_sprite: Sprite2D = $Sprite2D

# 初始化函数
func _ready():
	print("✅ [桌宠] ====== 桌宠主程序初始化完成 ========")
	# 1. 窗口基础配置
	init_window()
	# 2. 精灵居中显示
	center_sprite()
	# 3. 初始化附属脚本
	drag_script.init(self)
	# 4. 初始化鼠标穿透管理器
	passthrough_manager.init(self)
	# 5. 初始化桌宠鼠标管理器
	mouse_manager.init(self, pet_sprite, passthrough_manager)

# 窗口初始化（透明+无边框+全屏）
func init_window():
	# 获取屏幕尺寸
	var _screen_size_i: Vector2i = DisplayServer.screen_get_size()

	# 设置窗口属性
	var window = get_window()

	# 输出初始化信息
	print("📌 [窗口] 窗口尺寸：", window.size, "，位置：", window.position)
	print("📌 [窗口] 窗口属性 - 透明：", window.transparent)
	print("📌 [窗口] 窗口属性 - 置顶：", window.always_on_top)

# 精灵居中显示
func center_sprite():
	if pet_sprite:
		var screen_size_i: Vector2i = DisplayServer.screen_get_size()
		var screen_size: Vector2 = Vector2(screen_size_i.x, screen_size_i.y)
		# 直接设置精灵的全局位置为屏幕中心
		pet_sprite.global_position = screen_size / 2
		print("[精灵] 精灵全局位置：", pet_sprite.global_position)
		# 初始化精灵透明度
		set_sprite_transparency(0.5)

# 设置精灵透明度
func set_sprite_transparency(alpha: float):
	if pet_sprite:
		# 确保alpha值在有效范围内
		var clamped_alpha = max(0.0, min(1.0, alpha))
		# 设置精灵透明度
		pet_sprite.modulate = Color(1, 1, 1, clamped_alpha)
		print("[精灵] 精灵透明度设置为：", clamped_alpha)

# 每帧更新
func _process(_delta):
	# 持续更新拖动状态，确保精灵跟随鼠标移动
	drag_script.update_drag()

	# 更新鼠标穿透状态
	mouse_manager.update_mouse_passthrough()

# 转发Area2D的输入事件到拖动脚本
func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	drag_script.handle_area_input_event(event)