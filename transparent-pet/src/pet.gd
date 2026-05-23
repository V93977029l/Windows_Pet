extends Node2D

@onready var config = preload("res://src/pet_config.gd").new()
@onready var drag_controller = preload("res://src/drag_controller.gd").new()
@onready var passthrough_manager = preload("res://addons/mouse_passthrough/mouse_passthrough.gd").new()
@onready var mouse_manager = preload("res://src/mouse_manager.gd").new()
@onready var material_manager: MaterialManager = MaterialManager.new()
@onready var vector_renderer = preload("res://src/vector_renderer.gd").new()
@onready var tray_manager: Node = null
@onready var pet_sprite: Sprite2D = $Sprite2D

const SVG_PATH: String = "res://assets/icons/pet_sprite.svg"

func _ready():
	print("✅ [桌宠] ====== 桌宠主程序初始化完成 ========")
	
	set_process_input(true)
	
	vector_renderer.init(pet_sprite, SVG_PATH)
	material_manager.init(pet_sprite)
	init_materials()
	center_sprite()
	
	drag_controller.init(self)
	passthrough_manager.init(self)
	mouse_manager.init(self, pet_sprite, passthrough_manager)
	tray_manager = preload("res://src/tray_manager.gd").new()
	add_child(tray_manager)
	tray_manager.init(self)
	tray_manager.settings_requested.connect(_on_tray_settings_requested)
	tray_manager.exit_requested.connect(_on_tray_exit_requested)
	
	config.print_config()

func _on_tray_settings_requested():
	open_settings_window()

func _on_tray_exit_requested():
	get_tree().quit()

func init_materials():
	var preset_id = config.material_preset
	var preset = material_manager.get_preset_by_id(preset_id)
	if preset:
		material_manager.apply_preset(preset)
	else:
		var fallback = material_manager.get_preset_by_id("blue_slime")
		material_manager.apply_preset(fallback)

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

func _process(_delta: float):
	drag_controller.update_drag()
	mouse_manager.update_mouse_passthrough()

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	drag_controller.handle_area_input_event(event)

func _input(event: InputEvent):
	if event.is_action_pressed("OpenSettings"):
		open_settings_window()

func open_settings_window():
	var settings_scene = load("res://scenes/settings_window.tscn")
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

func set_always_on_top(enabled: bool):
	if owner:
		owner.get_window().always_on_top = enabled

func get_window_size() -> Vector2i:
	return owner.get_window().size if owner else Vector2i.ZERO

func get_window_position() -> Vector2i:
	return owner.get_window().position if owner else Vector2i.ZERO
