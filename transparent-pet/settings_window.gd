extends Window

var pet_node: Node2D = null
var config = null

@onready var scale_slider: HSlider = $Background/MainHBox/CenterVBox/Scale/HBox2/Slider2
@onready var scale_input: LineEdit = $Background/MainHBox/CenterVBox/Scale/HBox2/Input2
@onready var apply_scale_btn: Button = $Background/MainHBox/CenterVBox/Scale/ApplyScaleBtn
@onready var material_combo: OptionButton = $Background/MainHBox/CenterVBox/Material/Combo
@onready var dynamic_check: CheckButton = $Background/MainHBox/CenterVBox/DynamicEffect/Check
@onready var always_on_top_check: CheckButton = $Background/MainHBox/CenterVBox/AlwaysOnTop/Check
@onready var save_button: Button = $Background/MainHBox/CenterVBox/Buttons/Save
@onready var reset_button: Button = $Background/MainHBox/CenterVBox/Buttons/Reset

var _is_updating_ui: bool = false

func set_pet_node(pet: Node2D):
	pet_node = pet
	if pet_node:
		config = pet_node.config
		load_config()

func _ready():
	title = "桌宠设置"
	transparent = false
	always_on_top = true
	
	setup_connections()
	setup_material_combo()
	
	visible = true
	await get_tree().process_frame
	grab_focus()

func setup_connections():
	scale_slider.value_changed.connect(_on_scale_slider_changed)
	scale_input.text_changed.connect(_on_scale_input_changed)
	apply_scale_btn.pressed.connect(_on_apply_scale)
	material_combo.item_selected.connect(_on_material_changed)
	dynamic_check.toggled.connect(_on_dynamic_changed)
	always_on_top_check.toggled.connect(_on_always_on_top_changed)
	save_button.pressed.connect(_on_save)
	reset_button.pressed.connect(_on_reset)
	close_requested.connect(_on_close)

func setup_material_combo():
	material_combo.clear()
	material_combo.add_item("液态玻璃")
	material_combo.select(0)
	material_combo.disabled = true

func load_config():
	if not config:
		print("⚠️ [设置] 配置对象为空")
		return
	
	_is_updating_ui = true
	
	scale_slider.value = clamp(config.pet_scale, 0.2, 4.0)
	scale_input.text = format_float(config.pet_scale)
	
	material_combo.select(0)
	dynamic_check.button_pressed = config.enable_dynamic
	always_on_top_check.button_pressed = config.window_always_on_top
	
	_is_updating_ui = false

func format_float(value: float) -> String:
	return str(round(value * 100) / 100)

func _on_scale_slider_changed(value: float):
	if _is_updating_ui:
		return
	
	var rounded = clamp(value, 0.2, 4.0)
	_is_updating_ui = true
	scale_input.text = format_float(rounded)
	_is_updating_ui = false
	
	config.pet_scale = rounded

func _on_scale_input_changed(text: String):
	if _is_updating_ui:
		return
	
	if not text.is_valid_float():
		scale_input.text = format_float(config.pet_scale)
		return
	
	var value = text.to_float()
	if value < 0.2 or value > 4.0:
		scale_input.text = format_float(config.pet_scale)
		return
	
	_is_updating_ui = true
	scale_slider.value = value
	_is_updating_ui = false
	
	config.pet_scale = value

func _on_apply_scale():
	var value = config.pet_scale
	apply_high_res_scale(value)
	print("✅ [设置] 缩放已应用: ", value)

func _on_material_changed(index: int):
	if _is_updating_ui:
		return
	print("[设置] 材质选择: ", material_combo.get_item_text(index))

func _on_dynamic_changed(enabled: bool):
	if _is_updating_ui:
		return
	
	config.enable_dynamic = enabled
	apply_dynamic_effect(enabled)

func _on_always_on_top_changed(enabled: bool):
	if _is_updating_ui:
		return
	
	config.window_always_on_top = enabled
	apply_always_on_top(enabled)

func apply_scale(value: float):
	if not pet_node:
		print("⚠️ [设置] 无法应用缩放：pet_node 为空")
		return
	
	pet_node.update_pet_scale(value)

func apply_high_res_scale(value: float):
	if not pet_node:
		print("⚠️ [设置] 无法应用高分辨率缩放：pet_node 为空")
		return
	
	pet_node.apply_high_res_scale(value)

func apply_dynamic_effect(enabled: bool):
	if not pet_node:
		print("⚠️ [设置] 无法设置动态效果：pet_node 为空")
		return
	
	pet_node.material_manager.set_dynamic_enabled(enabled)

func apply_always_on_top(enabled: bool):
	if not pet_node:
		print("⚠️ [设置] 无法设置窗口置顶：pet_node 为空")
		return
	
	var window = pet_node.get_window()
	window.always_on_top = enabled

func _on_save():
	if not config:
		print("⚠️ [设置] 无法保存配置：config 为空")
		return
	
	config.save_config()
	print("✅ [设置] 配置已保存")

func _on_reset():
	config.pet_scale = 1.0
	config.enable_dynamic = true
	config.window_always_on_top = true
	
	load_config()
	
	apply_scale(config.pet_scale)
	apply_dynamic_effect(config.enable_dynamic)
	apply_always_on_top(config.window_always_on_top)
	
	print("✅ [设置] 已恢复默认配置")

func _on_close():
	queue_free()