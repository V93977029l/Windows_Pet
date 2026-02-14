extends Node2D

# 桌宠主程序
# 功能：透明窗口、精灵居中、鼠标拖动

@onready var drag_script = preload("res://pet_drag.gd").new()
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

# 窗口初始化（透明+无边框+全屏）
func init_window():
	# 获取屏幕尺寸
	var screen_size_i: Vector2i = DisplayServer.screen_get_size()

	# 设置窗口属性
	var window = get_window()
	window.size = screen_size_i
	window.position = Vector2i.ZERO
	window.borderless = true
	window.transparent = true
	window.transparent_bg = true
	window.always_on_top = true

	# 输出初始化信息
	print("📌 [窗口] 屏幕尺寸：", screen_size_i)
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
		print("🔧 [精灵] 精灵全局位置：", pet_sprite.global_position)

# 每帧更新
func _process(_delta):
	# 持续更新拖动状态，确保精灵跟随鼠标移动
	drag_script.update_drag()

# 转发Area2D的输入事件到拖动脚本
func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	drag_script.handle_area_input_event(event)
