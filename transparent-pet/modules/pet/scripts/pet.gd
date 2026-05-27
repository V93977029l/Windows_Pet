extends Node2D

@onready var config = preload("res://core/autoload/config_manager.gd").new()
@onready var passthrough_manager = preload("res://addons/mouse_passthrough/mouse_passthrough.gd").new()

@onready var slime_sprite: Sprite2D = $Slime

var display_controller = null
var interaction_controller = null
var effects_controller: PetEffectsAPI = null
var ui_controller = null
var tray_manager: Node = null

var glass_item: GlassItem = null

var draggable_list: Array = []

const SVG_PATH: String = "res://modules/pet/assets/pet_sprite.svg"


func _ready():
	set_process_input(true)

	# ── 1. 显示子系统 ──
	var VectorRendererCls = preload("res://modules/display/scripts/vector_renderer.gd")
	var vector_renderer = VectorRendererCls.new()
	vector_renderer.init(slime_sprite, SVG_PATH)

	var material_manager: MaterialManager = MaterialManager.new()
	material_manager.init(slime_sprite)

	display_controller = {
		"vector": vector_renderer,
		"material": material_manager
	}

	_init_materials()
	center_sprite()

	# ── 2. 交互子系统 ──
	var DragCtrl = preload("res://modules/interaction/scripts/drag_controller.gd")
	var drag_controller = DragCtrl.new()
	drag_controller.init(self)

	var MouseMgr = preload("res://modules/interaction/scripts/mouse_manager.gd")
	var mouse_manager = MouseMgr.new()
	mouse_manager.init(self, slime_sprite, passthrough_manager)

	drag_controller.update_throw_params(
		config.throw_gravity, config.throw_min_speed,
		config.throw_max_speed, config.throw_multiplier,
		config.throw_enabled
	)
	drag_controller.update_physics_params(
		config.physics_ground_bounce, config.physics_wall_bounce,
		config.physics_ground_friction, config.physics_fall_threshold
	)
	drag_controller.update_svg_params(
		config.svg_half_w_ratio, config.svg_bottom_offset_ratio,
		config.svg_fallback_size_x, config.svg_fallback_size_y
	)

	interaction_controller = {
		"drag": drag_controller,
		"mouse": mouse_manager
	}

	passthrough_manager.init(self)

	# ── 3. 特效子系统 ──
	var EffectsCtrl = preload("res://modules/effects/scripts/liquid_glass_controller.gd")
	effects_controller = EffectsCtrl.new()
	add_child(effects_controller)
	effects_controller.init(self, slime_sprite, config)

	# ── 4. 系统托盘 ──
	tray_manager = preload("res://core/services/tray_manager.gd").new()
	add_child(tray_manager)
	tray_manager.init(self)
	tray_manager.settings_requested.connect(_on_tray_settings_requested)
	tray_manager.exit_requested.connect(_on_tray_exit_requested)

	config.print_config()

	# ── 5. 液态玻璃预设激活 ──
	if config.slime_1_material == "slime_2":
		effects_controller.activate_effect("liquid_glass")

	_register_draggables()

	open_settings_window.call_deferred()


func _init_materials():
	var preset_id = config.slime_1_material
	var preset = display_controller.material.get_preset_by_id(preset_id)
	if preset:
		display_controller.material.apply_preset(preset)
	else:
		var fallback = display_controller.material.get_preset_by_id("slime_1")
		display_controller.material.apply_preset(fallback)


func center_sprite():
	if not slime_sprite:
		return

	var screen_size_i: Vector2i = DisplayServer.screen_get_size()
	var screen_size: Vector2 = Vector2(screen_size_i.x, screen_size_i.y)

	var target_x: float = screen_size.x / 2
	var target_y: float = screen_size.y / 2

	if config.window_initial_x >= 0:
		target_x = config.window_initial_x
	if config.window_initial_y >= 0:
		target_y = config.window_initial_y

	slime_sprite.global_position = Vector2(target_x, target_y)
	update_pet_scale(config.pet_scale)

	print("[精灵] 精灵全局位置：", slime_sprite.global_position)
	print("[精灵] 精灵缩放大小：", config.pet_scale)


func _process(delta: float):
	interaction_controller.drag.update_drag(delta)

	if effects_controller.has_active_effect():
		var dpr: float = get_tree().root.content_scale_factor
		effects_controller.sync_position(slime_sprite.global_position, dpr)

	interaction_controller.mouse.update_mouse_passthrough()


func _register_draggables():
	draggable_list.append({"sprite": slime_sprite, "id": "slime", "render": slime_sprite})
	print("✅ [碰撞链] 已注册 %d 个可拖拽物体" % draggable_list.size())


func _bring_to_front(_target_id: String):
	slime_sprite.z_index = 1
	if effects_controller:
		var renderer = effects_controller.get("liquid_glass_renderer")
		if renderer:
			renderer.z_index = 1


func _mouse_in_sprite(_sprite: Sprite2D) -> bool:
	return interaction_controller.mouse.is_mouse_over_any()


func _input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for entry in draggable_list:
				if _mouse_in_sprite(entry.sprite):
					_bring_to_front(entry.id)
					interaction_controller.drag.handle_area_input_event(event, entry.sprite)
					return
		else:
			interaction_controller.drag.handle_area_input_event(event, null)

	if event.is_action_pressed("OpenSettings"):
		open_settings_window()


# ── 公共 API ──

func update_pet_scale(new_scale: float):
	display_controller.vector.update_scale(new_scale)


func apply_high_res_scale(new_scale: float):
	display_controller.vector.apply_high_res_scale(new_scale)


func on_material_changed(preset_id: String):
	if preset_id == "slime_2":
		effects_controller.activate_effect("liquid_glass")
	else:
		effects_controller.deactivate_effect(preset_id)


func set_always_on_top(enabled: bool):
	if owner:
		owner.get_window().always_on_top = enabled


func get_window_size() -> Vector2i:
	return owner.get_window().size if owner else Vector2i.ZERO


func get_window_position() -> Vector2i:
	return owner.get_window().position if owner else Vector2i.ZERO


func get_sprite_global_position() -> Vector2:
	return slime_sprite.global_position if slime_sprite else Vector2.ZERO


func get_current_material_name(_slime_id: String = "slime_1") -> String:
	return display_controller.material.get_current_material_name()


func save_config():
	config.save_config()


func get_all_presets() -> Array:
	return display_controller.material.get_all_presets()


func get_preset_by_id(id: String):
	return display_controller.material.get_preset_by_id(id)


func apply_preset(preset) -> String:
	display_controller.material.apply_preset(preset)
	return preset.id if "id" in preset else ""


func set_breathing_enabled(enabled: bool):
	display_controller.material.set_breathing_enabled(enabled)


func set_motion_effect_enabled(enabled: bool):
	display_controller.material.set_motion_effect_enabled(enabled)


func get_throw_params() -> Dictionary:
	return {
		"enabled": config.throw_enabled,
		"gravity": config.throw_gravity,
		"min_speed": config.throw_min_speed,
		"max_speed": config.throw_max_speed,
		"multiplier": config.throw_multiplier
	}


func set_throw_params(params: Dictionary):
	config.throw_enabled = params.get("enabled", true)
	config.throw_gravity = params.get("gravity", 800.0)
	config.throw_min_speed = params.get("min_speed", 350.0)
	config.throw_max_speed = params.get("max_speed", 800.0)
	config.throw_multiplier = params.get("multiplier", 2.0)

	interaction_controller.drag.update_throw_params(
		config.throw_gravity, config.throw_min_speed,
		config.throw_max_speed, config.throw_multiplier,
		config.throw_enabled
	)


func update_throw_params(gravity: float, min_speed: float, max_speed: float, multiplier: float, enabled: bool):
	config.throw_gravity = gravity
	config.throw_min_speed = min_speed
	config.throw_max_speed = max_speed
	config.throw_multiplier = multiplier
	config.throw_enabled = enabled
	interaction_controller.drag.update_throw_params(gravity, min_speed, max_speed, multiplier, enabled)


# ── 托盘回调 ──

func _on_tray_settings_requested():
	open_settings_window()


func _on_tray_exit_requested():
	get_tree().quit()


# ── 设置窗口 ──

func open_settings_window():
	var settings_scene = load("res://modules/settings/ui/settings_window.tscn")
	if settings_scene:
		var settings_window = settings_scene.instantiate()
		settings_window.set_pet_node(self)
		get_tree().root.add_child(settings_window)

		var pet_pos = slime_sprite.global_position
		var settings_pos = Vector2(pet_pos.x + 50, pet_pos.y - 130)
		settings_window.position = settings_pos
