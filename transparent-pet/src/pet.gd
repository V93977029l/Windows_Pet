extends Node2D

@onready var config = preload("res://src/pet_config.gd").new()
@onready var drag_controller = preload("res://src/drag_controller.gd").new()
@onready var passthrough_manager = preload("res://addons/mouse_passthrough/mouse_passthrough.gd").new()
@onready var mouse_manager = preload("res://src/mouse_manager.gd").new()
@onready var material_manager: MaterialManager = MaterialManager.new()
@onready var vector_renderer = preload("res://src/vector_renderer.gd").new()
@onready var tray_manager: Node = null
@onready var pet_sprite: Sprite2D = $Blue
@onready var glass_sprite: Sprite2D = $LiquidGlassRenderer/Glass
@onready var liquid_renderer: Node2D = $LiquidGlassRenderer
var glass_item: GlassItem = null

var draggable_list: Array = []

const SVG_PATH: String = "res://assets/icons/pet_sprite.svg"

func _ready():
	print("✅ [桌宠] ====== 桌宠主程序初始化完成 ========")
	
	set_process_input(true)
	
	vector_renderer.init(pet_sprite, SVG_PATH)
	material_manager.init(pet_sprite)
	init_materials()
	center_sprite()
	
	glass_sprite.global_position = pet_sprite.global_position
	
	drag_controller.init(self)
	passthrough_manager.init(self)
	mouse_manager.init(self, pet_sprite, passthrough_manager)
	mouse_manager.set_glass_sprite(glass_sprite)
	tray_manager = preload("res://src/tray_manager.gd").new()
	add_child(tray_manager)
	tray_manager.init(self)
	tray_manager.settings_requested.connect(_on_tray_settings_requested)
	tray_manager.exit_requested.connect(_on_tray_exit_requested)
	
	config.print_config()
	
	_setup_liquid_glass_slime()
	_register_draggables()

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
	
	if glass_item:
		var dpr: float = get_tree().root.content_scale_factor
		glass_item.position = glass_sprite.global_position * dpr
		liquid_renderer.update_items_uniforms()
	
	mouse_manager.update_mouse_passthrough()

func _register_draggables():
	draggable_list.append({"sprite": pet_sprite, "id": "blue", "render": pet_sprite})
	draggable_list.append({"sprite": glass_sprite, "id": "glass", "render": liquid_renderer})
	draggable_list.sort_custom(func(a, b): return a.sprite.z_index > b.sprite.z_index)
	print("✅ [碰撞链] 已注册 %d 个可拖拽物体" % draggable_list.size())

func _on_draggable_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if not (event is InputEventMouseButton):
		return
	
	if event.pressed:
		for entry in draggable_list:
			if _mouse_in_sprite(entry.sprite):
				_bring_to_front(entry.id)
				drag_controller.handle_area_input_event(event, entry.sprite)
				return
	else:
		drag_controller.handle_area_input_event(event, null)

func _bring_to_front(target_id: String):
	for entry in draggable_list:
		entry.render.z_index = 1 if entry.id == target_id else 0
	draggable_list.sort_custom(func(a, b): return a.sprite.z_index > b.sprite.z_index)

func _mouse_in_sprite(sprite: Sprite2D) -> bool:
	if not sprite.texture:
		return false
	var mouse_pos = get_global_mouse_position()
	var rect = sprite.get_rect()
	var global_rect = Rect2(sprite.global_position - rect.size / 2, rect.size)
	if not global_rect.has_point(mouse_pos):
		return false
	var local_pos = sprite.to_local(mouse_pos)
	var tex_size = sprite.texture.get_size() * sprite.scale
	var px = int(local_pos.x + tex_size.x / 2)
	var py = int(local_pos.y + tex_size.y / 2)
	if px < 0 or px >= tex_size.x or py < 0 or py >= tex_size.y:
		return false
	var img = sprite.texture.get_image()
	return img.get_pixel(px, py).a > 0

func _input(event: InputEvent):
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		drag_controller.handle_area_input_event(event, null)
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

func _setup_liquid_glass_slime():
	if not liquid_renderer:
		return

	if not pet_sprite:
		return

	liquid_renderer.bg_type = 3
	liquid_renderer.blur_edge = true
	liquid_renderer.blur_radius = 2.0

	var glass_color = Color(0.3, 0.6, 0.9, 1.0)
	liquid_renderer.tint = glass_color
	liquid_renderer.tint_alpha = 0.35

	var item_manager = liquid_renderer.get_item_manager()
	item_manager.clear_all()

	var dpr: float = get_tree().root.content_scale_factor
	var pos = glass_sprite.global_position * dpr

	var slime_item = GlassItem.new()
	slime_item.shape_type = GlassItem.ShapeType.SLIME
	slime_item.position = pos
	slime_item.width = 200.0
	slime_item.height = 132.0
	slime_item.radius = 65.0
	slime_item.scale = config.pet_scale
	slime_item.enabled = true
	item_manager.add_item(slime_item)
	glass_item = slime_item

	liquid_renderer.update_items_uniforms()
	liquid_renderer.update_all_uniforms()

	print("✅ [液态玻璃] 已创建，跟1号史莱姆位置同步")
