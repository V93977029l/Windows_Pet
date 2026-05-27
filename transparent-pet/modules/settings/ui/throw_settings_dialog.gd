extends Window

var pet_node: Node2D = null
var config = null
var _is_updating_ui: bool = false
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
		config = pet_node.config
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
	if not config:
		return

	_is_updating_ui = true

	enable_check.button_pressed = config.throw_enabled
	gravity_slider.value = config.throw_gravity
	gravity_input.text = _fmt(config.throw_gravity)
	min_speed_slider.value = config.throw_min_speed
	min_speed_input.text = _fmt(config.throw_min_speed)
	max_speed_slider.value = config.throw_max_speed
	max_speed_input.text = _fmt(config.throw_max_speed)
	multiplier_slider.value = config.throw_multiplier
	multiplier_input.text = _fmt(config.throw_multiplier)

	_is_updating_ui = false


func _await_apply():
	config.throw_enabled = enable_check.button_pressed
	config.throw_gravity = gravity_slider.value
	config.throw_min_speed = min_speed_slider.value
	config.throw_max_speed = max_speed_slider.value
	config.throw_multiplier = multiplier_slider.value

	if pet_node and pet_node.has_method("update_throw_params"):
		pet_node.update_throw_params(
			config.throw_gravity,
			config.throw_min_speed,
			config.throw_max_speed,
			config.throw_multiplier,
			config.throw_enabled
		)


func _on_enable_changed(enabled: bool):
	if _is_updating_ui:
		return
	config.throw_enabled = enabled
	_await_apply()


func _on_gravity_slider_changed(value: float):
	if _is_updating_ui:
		return
	_is_updating_ui = true
	gravity_input.text = _fmt(value)
	_is_updating_ui = false
	config.throw_gravity = value
	_await_apply()


func _on_gravity_input_changed(text: String):
	if _is_updating_ui:
		return
	if not text.is_valid_float():
		return
	var value = text.to_float()
	if value < 100.0 or value > 3000.0:
		return
	_is_updating_ui = true
	gravity_slider.value = value
	_is_updating_ui = false
	config.throw_gravity = value
	_await_apply()


func _on_min_speed_slider_changed(value: float):
	if _is_updating_ui:
		return
	_is_updating_ui = true
	min_speed_input.text = _fmt(value)
	_is_updating_ui = false
	config.throw_min_speed = value
	_await_apply()


func _on_min_speed_input_changed(text: String):
	if _is_updating_ui:
		return
	if not text.is_valid_float():
		return
	var value = text.to_float()
	if value < 50.0 or value > 2000.0:
		return
	_is_updating_ui = true
	min_speed_slider.value = value
	_is_updating_ui = false
	config.throw_min_speed = value
	_await_apply()


func _on_max_speed_slider_changed(value: float):
	if _is_updating_ui:
		return
	_is_updating_ui = true
	max_speed_input.text = _fmt(value)
	_is_updating_ui = false
	config.throw_max_speed = value
	_await_apply()


func _on_max_speed_input_changed(text: String):
	if _is_updating_ui:
		return
	if not text.is_valid_float():
		return
	var value = text.to_float()
	if value < 200.0 or value > 3000.0:
		return
	_is_updating_ui = true
	max_speed_slider.value = value
	_is_updating_ui = false
	config.throw_max_speed = value
	_await_apply()


func _on_multiplier_slider_changed(value: float):
	if _is_updating_ui:
		return
	_is_updating_ui = true
	multiplier_input.text = _fmt(value)
	_is_updating_ui = false
	config.throw_multiplier = value
	_await_apply()


func _on_multiplier_input_changed(text: String):
	if _is_updating_ui:
		return
	if not text.is_valid_float():
		return
	var value = text.to_float()
	if value < 0.1 or value > 10.0:
		return
	_is_updating_ui = true
	multiplier_slider.value = value
	_is_updating_ui = false
	config.throw_multiplier = value
	_await_apply()


func _on_save():
	if not config:
		return
	config.save_config()
	print("✅ [抛射设置] 配置已保存")


func _on_reset():
	config.throw_enabled = true
	config.throw_gravity = 800.0
	config.throw_min_speed = 350.0
	config.throw_max_speed = 800.0
	config.throw_multiplier = 2.0
	load_config()
	_await_apply()
	print("✅ [抛射设置] 已恢复默认")


func _on_close():
	queue_free()


func _fmt(value: float) -> String:
	return str(round(value * 10) / 10)
