extends Node2D

# 核心修正：用new()实例化RefCounted脚本，完全删掉找空节点的代码
@onready var drag_script = preload("res://pet_drag.gd").new()
@onready var pet_sprite: Sprite2D = $Sprite2D  

func _ready():
	print("✅ ====== 桌宠主程序初始化完成 =======")
	# 1. 窗口基础配置（最终版，无属性错误）
	init_window()
	# 2. 初始化附属脚本（直接调用init，无需判空找节点）
	drag_script.init(self)

# 窗口初始化（4.x官方正确配置，透明+无边框+穿透）
func init_window():
	if pet_sprite and pet_sprite.texture:
		var sprite_size: Vector2 = pet_sprite.texture.get_size()
		var sprite_size_i: Vector2i = Vector2i(int(round(sprite_size.x)), int(round(sprite_size.y)))
		get_window().size = sprite_size_i
		var screen_size_i: Vector2i = DisplayServer.screen_get_size()
		var window_pos_i: Vector2i = (screen_size_i - sprite_size_i) / 2
		get_window().position = window_pos_i
		# Window属性最终版
		var window = get_window()
		window.borderless = true
		window.transparent = true
		window.transparent_bg = true
		# 4.x官方鼠标穿透方法
		DisplayServer.window_set_flag(
			window.get_window_id(), 
			DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, 
			true
		)
		print("📌 桌宠窗口尺寸：", sprite_size_i, "，位置：", window_pos_i)

# 转发Input事件到附属脚本（直接调用，无需判空）
func _input(event: InputEvent):
	drag_script.handle_drag_input(event)

# 转发Area2D的input_event信号到拖动脚本（直接调用，无需判空）
func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	drag_script.handle_area_input_event(event)
