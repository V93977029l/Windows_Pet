extends Node2D

@onready var config = preload("res://src/config/pet_config.gd").new()
@onready var drag_controller = preload("res://src/controllers/drag_controller.gd").new()
@onready var passthrough_manager = preload("res://addons/mouse_passthrough/mouse_passthrough.gd").new()
@onready var mouse_manager = preload("res://src/controllers/mouse_manager.gd").new()
@onready var material_manager = preload("res://src/managers/material_manager.gd").new()
@onready var vector_renderer = preload("res://src/controllers/vector_renderer.gd").new()
@onready var window_manager = preload("res://src/managers/window_manager.gd").new()
@onready var pet_sprite: Sprite2D = $Sprite2D

const SVG_PATH: String = "res://assets/icons/pet_sprite.svg"

func _ready():
	print("✅ [桌宠] ====== 桌宠主程序初始化完成 ========")
	config.print_config()
	
	window_manager.init(self)
	vector_renderer.init(pet_sprite, SVG_PATH)
	material_manager.init(pet_sprite)
	init_materials()
	center_sprite()
	
	drag_controller.init(self)
	passthrough_manager.init(self)
	mouse_manager.init(self, pet_sprite, passthrough_manager)

func init_materials():
	var preset = config.load_preset()
	material_manager.apply_preset(preset)

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
		update_pet_scale(config.pet_scale)
		
		print("[精灵] 精灵全局位置：", pet_sprite.global_position)
		print("[精灵] 精灵缩放大小：", config.pet_scale)

func get_current_material_name() -> String:
	return material_manager.get_current_material_name()

func _process(_delta):
	drag_controller.update_drag()
	mouse_manager.update_mouse_passthrough()

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	drag_controller.handle_area_input_event(event)

func _input(event: InputEvent):
	if event.is_action_pressed("OpenSettings"):
		open_settings_window()

func open_settings_window():
	var settings_scene = load("res://src/controllers/settings_window.tscn")
	if settings_scene:
		var settings_window = settings_scene.instantiate()
		get_tree().root.add_child(settings_window)
		settings_window.set_pet_node(self)
		
		var pet_pos = pet_sprite.global_position
		var settings_pos = Vector2(pet_pos.x + 50, pet_pos.y - 130)
		settings_window.position = settings_pos

func update_pet_scale(new_scale: float):
	vector_renderer.update_scale(new_scale)

func apply_high_res_scale(new_scale: float):
	vector_renderer.apply_high_res_scale(new_scale)