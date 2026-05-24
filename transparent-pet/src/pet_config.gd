extends RefCounted

var config: ConfigFile = ConfigFile.new()
var config_path: String = "res://data/pet_config.cfg"
var save_path: String = "user://pet_config.cfg"

var pet_scale: float = 1.0
var material_preset: String = "blue_slime"

var window_initial_x: int = -1
var window_initial_y: int = -1
var window_always_on_top: bool = true

func _init():
	load_config()

func load_config():
	var err = OK
	if FileAccess.file_exists(save_path):
		err = config.load(save_path)
	else:
		err = config.load(config_path)

	if err == OK:
		_read_pet_section()
		_read_window_section()
		print("✅ [配置] 配置文件加载成功")
	else:
		print("⚠️ [配置] 配置文件不存在或加载失败，使用默认值")
		_save_config()

func _read_pet_section():
	pet_scale = config.get_value("pet", "scale", 1.0)
	pet_scale = clamp(pet_scale, 0.2, 4.0)
	material_preset = config.get_value("pet", "material_preset", "blue_slime")

func _read_window_section():
	window_initial_x = config.get_value("window", "initial_x", -1)
	window_initial_y = config.get_value("window", "initial_y", -1)
	window_always_on_top = config.get_value("window", "always_on_top", true)

func _save_config():
	config.set_value("pet", "scale", pet_scale)
	config.set_value("pet", "material_preset", material_preset)
	config.set_value("window", "initial_x", window_initial_x)
	config.set_value("window", "initial_y", window_initial_y)
	config.set_value("window", "always_on_top", window_always_on_top)

	var err = config.save(save_path)
	if err == OK:
		print("✅ [配置] 配置文件已保存: ", save_path)
	else:
		printerr("[配置] 配置文件保存失败: ", save_path)

func save_config():
	_save_config()

func print_config():
	print("\n📋 [配置] 当前配置参数:")
	print("├── [pet]")
	print("│   ├── scale: ", pet_scale)
	print("│   └── material_preset: ", material_preset)
	print("└── [window]")
	print("    ├── initial_x: ", window_initial_x)
	print("    ├── initial_y: ", window_initial_y)
	print("    └── always_on_top: ", window_always_on_top)
	print()

func get_material_name() -> String:
	return "蓝色史莱姆"