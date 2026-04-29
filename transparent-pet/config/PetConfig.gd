extends RefCounted

var config: ConfigFile = ConfigFile.new()
var config_path: String = "res://config/pet_config.cfg"

var pet_initial_transparency: float = 0.5
var pet_scale: float = 1.0

var window_initial_x: int = -1
var window_initial_y: int = -1
var window_always_on_top: bool = true

func _init():
	load_config()

func load_config():
	var err = config.load(config_path)
	if err == OK:
		print("✅ [配置] 配置文件加载成功: ", config_path)
		_read_pet_section()
		_read_window_section()
	else:
		print("⚠️ [配置] 配置文件不存在或加载失败，使用默认值")
		_save_default_config()

func _read_pet_section():
	pet_initial_transparency = config.get_value("pet", "initial_transparency", 0.5)
	pet_scale = config.get_value("pet", "scale", 1.0)
	
	pet_initial_transparency = max(0.0, min(1.0, pet_initial_transparency))
	pet_scale = max(0.1, min(5.0, pet_scale))

func _read_window_section():
	window_initial_x = config.get_value("window", "initial_x", -1)
	window_initial_y = config.get_value("window", "initial_y", -1)
	window_always_on_top = config.get_value("window", "always_on_top", true)

func _save_default_config():
	config.set_value("pet", "initial_transparency", pet_initial_transparency)
	config.set_value("pet", "scale", pet_scale)
	
	config.set_value("window", "initial_x", window_initial_x)
	config.set_value("window", "initial_y", window_initial_y)
	config.set_value("window", "always_on_top", window_always_on_top)
	
	DirAccess.make_dir_recursive_absolute("res://config")
	
	var err = config.save(config_path)
	if err == OK:
		print("✅ [配置] 默认配置文件已创建: ", config_path)
	else:
		print("❌ [配置] 默认配置文件保存失败")

func print_config():
	print("\n📋 [配置] 当前配置参数:")
	print("├── [pet]")
	print("│   ├── initial_transparency: ", pet_initial_transparency)
	print("│   └── scale: ", pet_scale)
	print("└── [window]")
	print("    ├── initial_x: ", window_initial_x)
	print("    ├── initial_y: ", window_initial_y)
	print("    └── always_on_top: ", window_always_on_top)
	print()
