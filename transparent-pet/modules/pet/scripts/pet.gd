extends Node2D

@onready var passthrough_manager = preload("res://addons/mouse_passthrough/mouse_passthrough.gd").new()

@onready var slime_sprite: Sprite2D = $Slime

var display_controller = null
var interaction_controller = null
var effects_controller: PetEffectsAPI = null
var ui_controller = null
var tray_manager: Node = null

var draggable_list: Array = []

const SVG_PATH: String = ProjectConstants.SVG_PATH
const PetConsts = preload("res://modules/pet/scripts/pet_constants.gd")


func _ready():
	set_process_input(true)

	ConfigManager.load_defaults("pet")
	ConfigManager.load_defaults("window")
	ConfigManager.load_defaults("throw")
	ConfigManager.load_defaults("physics")
	ConfigManager.load_defaults("svg")
	ConfigManager.load_defaults("liquid_glass")

	# ── 1. 显示子系统 ──
	var vector_renderer = NodeUtils.create_and_init("res://modules/display/scripts/vector_renderer.gd", [slime_sprite, SVG_PATH])

	var material_manager: MaterialManager = MaterialManager.new()
	material_manager.init(slime_sprite)

	display_controller = {
		"vector": vector_renderer,
		"material": material_manager
	}

	_init_materials()
	center_sprite()

	# ── 2. 交互子系统 ──
	var drag_controller = NodeUtils.create_and_init("res://modules/interaction/scripts/drag_controller.gd", [self])

	var MouseMgr = preload("res://modules/interaction/scripts/mouse_manager.gd")
	var mouse_manager = MouseMgr.new()
	mouse_manager.init(self, slime_sprite, passthrough_manager)

	drag_controller.update_throw_params(
		ConfigManager.cfg_get("throw", "throw_gravity", PetConsts.THROW_GRAVITY_DEFAULT),
		ConfigManager.cfg_get("throw", "throw_min_speed", PetConsts.THROW_MIN_SPEED_DEFAULT),
		ConfigManager.cfg_get("throw", "throw_max_speed", PetConsts.THROW_MAX_SPEED_DEFAULT),
		ConfigManager.cfg_get("throw", "throw_multiplier", PetConsts.THROW_MULTIPLIER_DEFAULT),
		ConfigManager.cfg_get("throw", "throw_enabled", PetConsts.THROW_ENABLED_DEFAULT)
	)
	drag_controller.update_physics_params(
		ConfigManager.cfg_get("physics", "physics_ground_bounce", PetConsts.PHYSICS_GROUND_BOUNCE_DEFAULT),
		ConfigManager.cfg_get("physics", "physics_wall_bounce", PetConsts.PHYSICS_WALL_BOUNCE_DEFAULT),
		ConfigManager.cfg_get("physics", "physics_ground_friction", PetConsts.PHYSICS_GROUND_FRICTION_DEFAULT),
		ConfigManager.cfg_get("physics", "physics_fall_threshold", PetConsts.PHYSICS_FALL_THRESHOLD_DEFAULT)
	)
	drag_controller.update_svg_params(
		ConfigManager.cfg_get("svg", "svg_half_w_ratio", PetConsts.SVG_HALF_W_RATIO_DEFAULT),
		ConfigManager.cfg_get("svg", "svg_bottom_offset_ratio", PetConsts.SVG_BOTTOM_OFFSET_RATIO_DEFAULT),
		ConfigManager.cfg_get("svg", "svg_fallback_size_x", PetConsts.SVG_FALLBACK_SIZE_X_DEFAULT),
		ConfigManager.cfg_get("svg", "svg_fallback_size_y", PetConsts.SVG_FALLBACK_SIZE_Y_DEFAULT)
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
	effects_controller.init(self, slime_sprite)

	# ── 4. 系统托盘 ──
	tray_manager = NodeUtils.create_and_init("res://core/services/tray_manager.gd", [self])
	add_child(tray_manager)
	tray_manager.settings_requested.connect(_on_tray_settings_requested)
	tray_manager.exit_requested.connect(_on_tray_exit_requested)

	# ── 4.5 订阅 UI 事件（EventBus 解耦）──
	_subscribe_ui_events()

	# ── 5. 液态玻璃预设激活 ──
	if ConfigManager.cfg_get("pet", "slime_1_material", "slime_1") == "slime_2":
		effects_controller.activate_effect("liquid_glass")

	_register_draggables()

	if ConfigManager.cfg_get("window", "open_settings_on_start", PetConsts.WINDOW_OPEN_SETTINGS_DEFAULT):
		open_settings_window.call_deferred()


func _init_materials():
	var preset_id = ConfigManager.cfg_get("pet", "slime_1_material", "slime_1")
	var preset = display_controller.material.get_preset_by_id(preset_id)
	if preset:
		display_controller.material.apply_preset(preset)
	else:
		var fallback = display_controller.material.get_preset_by_id("slime_1")
		display_controller.material.apply_preset(fallback)


func center_sprite():
	if not slime_sprite:
		return

	var screen_size := DisplayUtils.get_screen_size()

	var target_x: float = screen_size.x / 2
	var target_y: float = screen_size.y / 2

	if ConfigManager.cfg_get("window", "window_initial_x", -1) >= 0:
		target_x = ConfigManager.cfg_get("window", "window_initial_x", -1)
	if ConfigManager.cfg_get("window", "window_initial_y", -1) >= 0:
		target_y = ConfigManager.cfg_get("window", "window_initial_y", -1)

	slime_sprite.global_position = Vector2(target_x, target_y)
	update_pet_scale(ConfigManager.cfg_get("pet", "pet_scale", PetConsts.PET_SCALE_DEFAULT))

	# 加载上次关闭时的位置
	var saved_pos: Vector2 = DataManager.data_get("pet_position", Vector2.INF)
	if saved_pos != Vector2.INF:
		slime_sprite.global_position = saved_pos
		print("[精灵] 恢复保存位置：", saved_pos)

	print("[精灵] 精灵全局位置：", slime_sprite.global_position)
	print("[精灵] 精灵缩放大小：", ConfigManager.cfg_get("pet", "pet_scale", PetConsts.PET_SCALE_DEFAULT))


func _process(delta: float):
	interaction_controller.drag.update_drag(delta)

	if effects_controller.has_active_effect():
		var dpr := DisplayUtils.get_dpr(self)
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
	return DisplayUtils.get_window_size(self)


func get_window_position() -> Vector2i:
	return DisplayUtils.get_window_position(self)


func get_sprite_global_position() -> Vector2:
	return slime_sprite.global_position if slime_sprite else Vector2.ZERO


func get_current_material_name(_slime_id: String = "slime_1") -> String:
	return display_controller.material.get_current_material_name()


func save_config():
	ConfigManager.save_config()
	DataManager.data_set("pet_position", slime_sprite.global_position if slime_sprite else Vector2.ZERO)
	DataManager.save_data()


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
		"enabled": ConfigManager.cfg_get("throw", "throw_enabled", PetConsts.THROW_ENABLED_DEFAULT),
		"gravity": ConfigManager.cfg_get("throw", "throw_gravity", PetConsts.THROW_GRAVITY_DEFAULT),
		"min_speed": ConfigManager.cfg_get("throw", "throw_min_speed", PetConsts.THROW_MIN_SPEED_DEFAULT),
		"max_speed": ConfigManager.cfg_get("throw", "throw_max_speed", PetConsts.THROW_MAX_SPEED_DEFAULT),
		"multiplier": ConfigManager.cfg_get("throw", "throw_multiplier", PetConsts.THROW_MULTIPLIER_DEFAULT)
	}


func set_throw_params(params: Dictionary):
	ConfigManager.cfg_set("throw", "throw_enabled", params.get("enabled", PetConsts.THROW_ENABLED_DEFAULT))
	ConfigManager.cfg_set("throw", "throw_gravity", params.get("gravity", PetConsts.THROW_GRAVITY_DEFAULT))
	ConfigManager.cfg_set("throw", "throw_min_speed", params.get("min_speed", PetConsts.THROW_MIN_SPEED_DEFAULT))
	ConfigManager.cfg_set("throw", "throw_max_speed", params.get("max_speed", PetConsts.THROW_MAX_SPEED_DEFAULT))
	ConfigManager.cfg_set("throw", "throw_multiplier", params.get("multiplier", PetConsts.THROW_MULTIPLIER_DEFAULT))

	interaction_controller.drag.update_throw_params(
		ConfigManager.cfg_get("throw", "throw_gravity", PetConsts.THROW_GRAVITY_DEFAULT),
		ConfigManager.cfg_get("throw", "throw_min_speed", PetConsts.THROW_MIN_SPEED_DEFAULT),
		ConfigManager.cfg_get("throw", "throw_max_speed", PetConsts.THROW_MAX_SPEED_DEFAULT),
		ConfigManager.cfg_get("throw", "throw_multiplier", PetConsts.THROW_MULTIPLIER_DEFAULT),
		ConfigManager.cfg_get("throw", "throw_enabled", PetConsts.THROW_ENABLED_DEFAULT)
	)


func update_throw_params(gravity: float, min_speed: float, max_speed: float, multiplier: float, enabled: bool):
	ConfigManager.cfg_set("throw", "throw_gravity", gravity)
	ConfigManager.cfg_set("throw", "throw_min_speed", min_speed)
	ConfigManager.cfg_set("throw", "throw_max_speed", max_speed)
	ConfigManager.cfg_set("throw", "throw_multiplier", multiplier)
	ConfigManager.cfg_set("throw", "throw_enabled", enabled)
	interaction_controller.drag.update_throw_params(gravity, min_speed, max_speed, multiplier, enabled)


# ── 托盘回调 ──

func _on_tray_settings_requested():
	open_settings_window()


func _on_tray_exit_requested():
	save_config()
	get_tree().quit()


# ── 设置窗口 ──

func open_settings_window():
	var settings_window = NodeUtils.instantiate_scene(ProjectConstants.SETTINGS_WINDOW_SCENE)
	if settings_window:
		settings_window.set_pet_node(self)
		get_tree().root.add_child(settings_window)

		var pet_pos = slime_sprite.global_position
		var settings_pos = pet_pos + ProjectConstants.SETTINGS_WINDOW_OFFSET
		settings_window.position = Vector2i(int(settings_pos.x), int(settings_pos.y))


# ── EventBus 订阅 ──

func _subscribe_ui_events():
	EventBus.subscribe("pet_scale_apply", _on_event_scale_apply)
	EventBus.subscribe("pet_material_changed", _on_event_material_changed)
	EventBus.subscribe("pet_breathing_toggled", _on_event_breathing_toggled)
	EventBus.subscribe("pet_motion_effect_toggled", _on_event_motion_effect_toggled)
	EventBus.subscribe("window_always_on_top_changed", _on_event_always_on_top)
	EventBus.subscribe("settings_save_requested", _on_event_settings_save)
	EventBus.subscribe("settings_reset_requested", _on_event_settings_reset)
	EventBus.subscribe("throw_params_changed", _on_event_throw_params)
	print("✅ [EventBus] UI 事件订阅完成")


func _on_event_scale_apply(payload: Dictionary):
	var new_scale: float = payload.get("scale", 1.0)
	update_pet_scale(new_scale)
	apply_high_res_scale(new_scale)


func _on_event_material_changed(payload: Dictionary):
	var preset = payload.get("preset")
	var preset_id: String = payload.get("preset_id", "")
	if preset:
		apply_preset(preset)
	on_material_changed(preset_id)


func _on_event_breathing_toggled(payload: Dictionary):
	set_breathing_enabled(payload.get("enabled", true))


func _on_event_motion_effect_toggled(payload: Dictionary):
	set_motion_effect_enabled(payload.get("enabled", true))


func _on_event_always_on_top(payload: Dictionary):
	set_always_on_top(payload.get("enabled", true))


func _on_event_settings_save(_payload = null):
	save_config()


func _on_event_settings_reset(_payload = null):
	update_pet_scale(ConfigManager.cfg_get("pet", "pet_scale", PetConsts.PET_SCALE_DEFAULT))
	apply_high_res_scale(ConfigManager.cfg_get("pet", "pet_scale", PetConsts.PET_SCALE_DEFAULT))
	set_breathing_enabled(true)
	set_motion_effect_enabled(true)
	set_always_on_top(ConfigManager.cfg_get("window", "window_always_on_top", PetConsts.WINDOW_ALWAYS_ON_TOP_DEFAULT))


func _on_event_throw_params(payload: Dictionary):
	update_throw_params(
		payload.get("gravity", PetConsts.THROW_GRAVITY_DEFAULT),
		payload.get("min_speed", PetConsts.THROW_MIN_SPEED_DEFAULT),
		payload.get("max_speed", PetConsts.THROW_MAX_SPEED_DEFAULT),
		payload.get("multiplier", PetConsts.THROW_MULTIPLIER_DEFAULT),
		payload.get("enabled", PetConsts.THROW_ENABLED_DEFAULT)
	)
