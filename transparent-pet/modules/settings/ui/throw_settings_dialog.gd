extends Window

const PetConsts = preload("res://modules/pet/scripts/pet_constants.gd")

var pet_node: Node2D = null
var _update_guard: UIUtils.UIUpdateGuard = UIUtils.UIUpdateGuard.new()
var _pending_setup: bool = false

@onready var enable_check: CheckButton = $Background/VBox/Enable/HBox/Check
@onready var gravity_slider: HSlider = $Background/VBox/Gravity/HBox/Slider
@onready var gravity_input: LineEdit = $Background/VBox/Gravity/HBox/Input
@onready var min_speed_slider: HSlider = $Background/VBox/MinSpeed/HBox/Slider
@onready var min_speed_input: LineEdit = $Background/VBox/MinSpeed/HBox/Input
@onready var max_speed_slider: HSlider = $Background/VBox/MaxSpeed/HBox/Slider
@onready var max_speed_input: LineEdit = $Background/VBox/MaxSpeed/HBox/Input
@onready var multiplier_slider: HSlider = $Background/VBox/Multiplier/HBox/Slider
@onready var multiplier_input: LineEdit = $Background/VBox/Multiplier/HBox/Input
@onready var save_btn: Button = $Background/VBox/Buttons/Save
@onready var reset_btn: Button = $Background/VBox/Buttons/Reset


func set_pet_node(pet: Node2D):
	pet_node = pet
	if pet_node:
		_pending_setup = true


func _ready():
	title = "抛射参数设置"
	transparent = false
	always_on_top = true

	if _pending_setup:
		load_config()
		_pending_setup = false

	enable_check.toggled.connect(_on_enable_changed)
	gravity_slider.value_changed.connect(_on_gravity_slider_changed)
	gravity_input.text_changed.connect(_on_gravity_input_changed)
	min_speed_slider.value_changed.connect(_on_min_speed_slider_changed)
	min_speed_input.text_changed.connect(_on_min_speed_input_changed)
	max_speed_slider.value_changed.connect(_on_max_speed_slider_changed)
	max_speed_input.text_changed.connect(_on_max_speed_input_changed)
	multiplier_slider.value_changed.connect(_on_multiplier_slider_changed)
	multiplier_input.text_changed.connect(_on_multiplier_input_changed)
	save_btn.pressed.connect(_on_save)
	reset_btn.pressed.connect(_on_reset)
	close_requested.connect(_on_close)


func load_config():
	_update_guard.try_lock()

	enable_check.button_pressed = ConfigManager.cfg_get("throw", "throw_enabled", PetConsts.THROW_ENABLED_DEFAULT)
	gravity_slider.value = ConfigManager.cfg_get("throw", "throw_gravity", PetConsts.THROW_GRAVITY_DEFAULT)
	gravity_input.text = NumberUtils.format_float(ConfigManager.cfg_get("throw", "throw_gravity", PetConsts.THROW_GRAVITY_DEFAULT), 1)
	min_speed_slider.value = ConfigManager.cfg_get("throw", "throw_min_speed", PetConsts.THROW_MIN_SPEED_DEFAULT)
	min_speed_input.text = NumberUtils.format_float(ConfigManager.cfg_get("throw", "throw_min_speed", PetConsts.THROW_MIN_SPEED_DEFAULT), 1)
	max_speed_slider.value = ConfigManager.cfg_get("throw", "throw_max_speed", PetConsts.THROW_MAX_SPEED_DEFAULT)
	max_speed_input.text = NumberUtils.format_float(ConfigManager.cfg_get("throw", "throw_max_speed", PetConsts.THROW_MAX_SPEED_DEFAULT), 1)
	multiplier_slider.value = ConfigManager.cfg_get("throw", "throw_multiplier", PetConsts.THROW_MULTIPLIER_DEFAULT)
	multiplier_input.text = NumberUtils.format_float(ConfigManager.cfg_get("throw", "throw_multiplier", PetConsts.THROW_MULTIPLIER_DEFAULT), 1)

	_update_guard.unlock()


func _await_apply():
	ConfigManager.cfg_set("throw", "throw_enabled", enable_check.button_pressed)
	ConfigManager.cfg_set("throw", "throw_gravity", gravity_slider.value)
	ConfigManager.cfg_set("throw", "throw_min_speed", min_speed_slider.value)
	ConfigManager.cfg_set("throw", "throw_max_speed", max_speed_slider.value)
	ConfigManager.cfg_set("throw", "throw_multiplier", multiplier_slider.value)

	EventBus.publish("throw_params_changed", {
		"gravity": gravity_slider.value,
		"min_speed": min_speed_slider.value,
		"max_speed": max_speed_slider.value,
		"multiplier": multiplier_slider.value,
		"enabled": enable_check.button_pressed
	})


func _on_enable_changed(enabled: bool):
	if _update_guard.is_guarded():
		return
	ConfigManager.cfg_set("throw", "throw_enabled", enabled)
	_await_apply()


func _on_gravity_slider_changed(value: float):
	if _update_guard.is_guarded():
		return
	_update_guard.try_lock()
	gravity_input.text = NumberUtils.format_float(value, 1)
	_update_guard.unlock()
	ConfigManager.cfg_set("throw", "throw_gravity", value)
	_await_apply()


func _on_gravity_input_changed(text: String):
	if _update_guard.is_guarded():
		return
	if not text.is_valid_float():
		return
	var value = text.to_float()
	if value < 100.0 or value > 3000.0:
		return
	_update_guard.try_lock()
	gravity_slider.value = value
	_update_guard.unlock()
	ConfigManager.cfg_set("throw", "throw_gravity", value)
	_await_apply()


func _on_min_speed_slider_changed(value: float):
	if _update_guard.is_guarded():
		return
	_update_guard.try_lock()
	min_speed_input.text = NumberUtils.format_float(value, 1)
	_update_guard.unlock()
	ConfigManager.cfg_set("throw", "throw_min_speed", value)
	_await_apply()


func _on_min_speed_input_changed(text: String):
	if _update_guard.is_guarded():
		return
	if not text.is_valid_float():
		return
	var value = text.to_float()
	if value < 50.0 or value > 2000.0:
		return
	_update_guard.try_lock()
	min_speed_slider.value = value
	_update_guard.unlock()
	ConfigManager.cfg_set("throw", "throw_min_speed", value)
	_await_apply()


func _on_max_speed_slider_changed(value: float):
	if _update_guard.is_guarded():
		return
	_update_guard.try_lock()
	max_speed_input.text = NumberUtils.format_float(value, 1)
	_update_guard.unlock()
	ConfigManager.cfg_set("throw", "throw_max_speed", value)
	_await_apply()


func _on_max_speed_input_changed(text: String):
	if _update_guard.is_guarded():
		return
	if not text.is_valid_float():
		return
	var value = text.to_float()
	if value < 200.0 or value > 3000.0:
		return
	_update_guard.try_lock()
	max_speed_slider.value = value
	_update_guard.unlock()
	ConfigManager.cfg_set("throw", "throw_max_speed", value)
	_await_apply()


func _on_multiplier_slider_changed(value: float):
	if _update_guard.is_guarded():
		return
	_update_guard.try_lock()
	multiplier_input.text = NumberUtils.format_float(value, 1)
	_update_guard.unlock()
	ConfigManager.cfg_set("throw", "throw_multiplier", value)
	_await_apply()


func _on_multiplier_input_changed(text: String):
	if _update_guard.is_guarded():
		return
	if not text.is_valid_float():
		return
	var value = text.to_float()
	if value < 0.1 or value > 10.0:
		return
	_update_guard.try_lock()
	multiplier_slider.value = value
	_update_guard.unlock()
	ConfigManager.cfg_set("throw", "throw_multiplier", value)
	_await_apply()


func _on_save():
	ConfigManager.save_config()
	print("✅ [抛射设置] 配置已保存")


func _on_reset():
	ConfigManager.cfg_set("throw", "throw_enabled", PetConsts.THROW_ENABLED_DEFAULT)
	ConfigManager.cfg_set("throw", "throw_gravity", PetConsts.THROW_GRAVITY_DEFAULT)
	ConfigManager.cfg_set("throw", "throw_min_speed", PetConsts.THROW_MIN_SPEED_DEFAULT)
	ConfigManager.cfg_set("throw", "throw_max_speed", PetConsts.THROW_MAX_SPEED_DEFAULT)
	ConfigManager.cfg_set("throw", "throw_multiplier", PetConsts.THROW_MULTIPLIER_DEFAULT)
	load_config()
	_await_apply()
	print("✅ [抛射设置] 已恢复默认")


func _on_close():
	queue_free()
