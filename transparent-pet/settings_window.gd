extends Window

@onready var config = preload("res://config/PetConfig.gd").new()

@onready var transparency_slider: HSlider = $VBox/Transparency/Slider
@onready var transparency_value: Label = $VBox/Transparency/Value
@onready var scale_slider: HSlider = $VBox/Scale/Slider
@onready var scale_value: Label = $VBox/Scale/Value
@onready var material_combo: OptionButton = $VBox/Material/Combo
@onready var always_on_top_check: CheckButton = $VBox/AlwaysOnTop/Check
@onready var save_button: Button = $VBox/Buttons/Save
@onready var close_button: Button = $VBox/Buttons/Close

func _ready():
	title = "Pet Settings Config"
	transparent = false
	
	material_combo.add_item("Liquid Glass")
	material_combo.add_item("Frosted Glass")
	material_combo.add_item("Crystal Glass")
	material_combo.add_item("Aurora Glass")
	
	load_config()
	
	transparency_slider.value_changed.connect(_on_transparency_changed)
	scale_slider.value_changed.connect(_on_scale_changed)
	material_combo.item_selected.connect(_on_material_changed)
	always_on_top_check.toggled.connect(_on_always_on_top_changed)
	save_button.pressed.connect(_on_save)
	close_button.pressed.connect(_on_close)
	
	visible = true

func load_config():
	transparency_slider.value = config.pet_initial_transparency
	transparency_value.text = str(round(config.pet_initial_transparency * 100) / 100)
	
	scale_slider.value = config.pet_scale
	scale_value.text = str(round(config.pet_scale * 100) / 100)
	
	material_combo.select(config.current_material - 1)
	always_on_top_check.button_pressed = config.window_always_on_top

func _on_transparency_changed(value: float):
	transparency_value.text = str(round(value * 100) / 100)
	config.pet_initial_transparency = value

func _on_scale_changed(value: float):
	scale_value.text = str(round(value * 100) / 100)
	config.pet_scale = value

func _on_material_changed(index: int):
	config.current_material = index + 1

func _on_always_on_top_changed(enabled: bool):
	config.window_always_on_top = enabled

func _on_save():
	config.save_config()
	print("Config saved")

func _on_close():
	queue_free()
