extends Node2D

@onready var config = preload("res://config/PetConfig.gd").new()
@onready var drag_script = preload("res://pet_drag.gd").new()
@onready var passthrough_manager = preload("res://addons/mouse_passthrough/mouse_passthrough.gd").new()
@onready var mouse_manager = preload("res://pet_mouse_manager.gd").new()
@onready var pet_sprite: Sprite2D = $Sprite2D

func _ready():
	print("✅ [桌宠] ====== 桌宠主程序初始化完成 ========")
	config.print_config()
	
	init_window()
	center_sprite()
	
	drag_script.init(self)
	passthrough_manager.init(self)
	mouse_manager.init(self, pet_sprite, passthrough_manager)

func init_window():
	var window = get_window()
	window.always_on_top = config.window_always_on_top
	
	print("📌 [窗口] 窗口尺寸：", window.size, "，位置：", window.position)
	print("📌 [窗口] 窗口属性 - 透明：", window.transparent)
	print("📌 [窗口] 窗口属性 - 置顶：", window.always_on_top)

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
		
		set_sprite_transparency(config.pet_initial_transparency)

func set_sprite_transparency(alpha: float):
	if pet_sprite:
		var clamped_alpha = max(0.0, min(1.0, alpha))
		pet_sprite.modulate = Color(1, 1, 1, clamped_alpha)
		print("[精灵] 精灵透明度设置为：", clamped_alpha)

func _process(_delta):
	drag_script.update_drag()
	mouse_manager.update_mouse_passthrough()

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	drag_script.handle_area_input_event(event)