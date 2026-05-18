extends Window

var pet_node: Node2D = null
var config = null

@onready var transparency_slider: HSlider = $Background/MainHBox/CenterVBox/Transparency/HBox/Slider
@onready var transparency_input: LineEdit = $Background/MainHBox/CenterVBox/Transparency/HBox/Input
@onready var scale_slider: HSlider = $Background/MainHBox/CenterVBox/Scale/HBox2/Slider2
@onready var scale_input: LineEdit = $Background/MainHBox/CenterVBox/Scale/HBox2/Input2
@onready var apply_scale_btn: Button = $Background/MainHBox/CenterVBox/Scale/ApplyScaleBtn
@onready var material_combo: OptionButton = $Background/MainHBox/CenterVBox/Material/Combo
@onready var always_on_top_check: CheckButton = $Background/MainHBox/CenterVBox/AlwaysOnTop/Check
@onready var save_button: Button = $Background/MainHBox/CenterVBox/Buttons/Save
@onready var reset_button: Button = $Background/MainHBox/CenterVBox/Buttons/Reset
@onready var close_button: Button = $Background/MainHBox/CenterVBox/Buttons/Close

var is_updating_ui: bool = false

func set_pet_node(pet: Node2D):
	pet_node = pet
	if pet_node:
		config = pet_node.config
		load_config()

func _ready():
	title = "桌宠设置"
	transparent = false
	always_on_top = true
	
	material_combo.add_item("液态玻璃")
	material_combo.add_item("毛玻璃")
	material_combo.add_item("水晶玻璃")
	material_combo.add_item("极光玻璃")
	
	transparency_slider.value_changed.connect(_on_transparency_slider_changed)
	transparency_input.text_changed.connect(_on_transparency_input_changed)
	scale_slider.value_changed.connect(_on_scale_slider_changed)
	scale_input.text_changed.connect(_on_scale_input_changed)
	apply_scale_btn.pressed.connect(_on_apply_scale)
	material_combo.item_selected.connect(_on_material_changed)
	always_on_top_check.toggled.connect(_on_always_on_top_changed)
	save_button.pressed.connect(_on_save)
	reset_button.pressed.connect(_on_reset)
	close_button.pressed.connect(_on_close)
	
	visible = true
	
	await get_tree().process_frame
	grab_focus()

func load_config():
	if not config:
		return
	
	is_updating_ui = true
	
	transparency_slider.value = config.pet_initial_transparency
	transparency_input.text = str(round(config.pet_initial_transparency * 100) / 100)
	
	scale_slider.value = config.pet_scale
	scale_input.text = str(round(config.pet_scale * 100) / 100)
	
	material_combo.select(config.current_material - 1)
	always_on_top_check.button_pressed = config.window_always_on_top
	
	is_updating_ui = false

func _on_transparency_slider_changed(value: float):
	if is_updating_ui:
		return
	
	var rounded = round(value * 100) / 100
	is_updating_ui = true
	transparency_input.text = str(rounded)
	is_updating_ui = false
	
	config.pet_initial_transparency = rounded
	apply_transparency(rounded)

func _on_transparency_input_changed(text: String):
	if is_updating_ui:
		return
	
	var value = text.to_float()
	if value >= 0.0 and value <= 1.0:
		is_updating_ui = true
		transparency_slider.value = value
		is_updating_ui = false
		
		config.pet_initial_transparency = value
		apply_transparency(value)

func _on_scale_slider_changed(value: float):
	if is_updating_ui:
		return
	
	var rounded = round(value * 100) / 100
	is_updating_ui = true
	scale_input.text = str(rounded)
	is_updating_ui = false
	
	config.pet_scale = rounded

func _on_scale_input_changed(text: String):
	if is_updating_ui:
		return
	
	var value = text.to_float()
	if value >= 0.1 and value <= 3.0:
		is_updating_ui = true
		scale_slider.value = value
		is_updating_ui = false
		
		config.pet_scale = value

func _on_apply_scale():
	var value = config.pet_scale
	apply_high_res_scale(value)
	print("✅ [设置] 缩放已应用: ", value)

func _on_material_changed(index: int):
	if is_updating_ui:
		return
	
	config.current_material = index + 1
	apply_material(index + 1)

func _on_always_on_top_changed(enabled: bool):
	if is_updating_ui:
		return
	
	config.window_always_on_top = enabled
	apply_always_on_top(enabled)

func apply_transparency(value: float):
	if pet_node and pet_node.pet_sprite:
		var material = pet_node.pet_sprite.material
		if material and material is ShaderMaterial:
			if config.current_material == 2:
				material.set_shader_parameter("opacity", value)
			else:
				var current_color = material.get_shader_parameter("glass_color")
				material.set_shader_parameter("glass_color", Vector4(current_color.x, current_color.y, current_color.z, value))

func apply_scale(value: float):
	if pet_node:
		pet_node.update_pet_scale(value)

func apply_high_res_scale(value: float):
	if pet_node:
		pet_node.apply_high_res_scale(value)

func apply_material(material_id: int):
	if pet_node and pet_node.pet_sprite:
		var current_scale = pet_node.pet_sprite.scale.x
		var preset = config.load_preset(material_id)
		pet_node.material_manager.apply_preset(preset, material_id)
		pet_node.current_material_id = material_id
		pet_node.pet_sprite.scale = Vector2(current_scale, current_scale)
		apply_transparency(config.pet_initial_transparency)

func apply_always_on_top(enabled: bool):
	if pet_node:
		var window = pet_node.get_window()
		window.always_on_top = enabled

func _on_save():
	if config:
		config.save_config()
		print("✅ [设置] 配置已保存")

func _on_reset():
	config.pet_initial_transparency = 0.5
	config.pet_scale = 1.0
	config.current_material = 1
	config.window_always_on_top = true
	
	load_config()
	
	apply_transparency(0.5)
	apply_scale(1.0)
	apply_material(1)
	apply_always_on_top(true)
	
	print("✅ [设置] 已恢复默认配置")

func _on_close():
	queue_free()
