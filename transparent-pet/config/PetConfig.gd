extends RefCounted

var config: ConfigFile = ConfigFile.new()
var config_path: String = "res://config/pet_config.cfg"

var pet_initial_transparency: float = 0.5
var pet_scale: float = 1.0
var current_material: int = 1

var glass_color: Color = Color(0.1, 0.2, 0.4, 0.4)
var edge_glow: float = 0.7
var highlight_intensity: float = 0.9
var liquid_wobble: float = 0.2
var wobble_speed: float = 2.0
var frost_intensity: float = 0.7
var noise_scale: float = 0.5

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
		apply_material_preset()
	else:
		print("⚠️ [配置] 配置文件不存在或加载失败，使用默认值")
		_save_config()

func _read_pet_section():
	pet_initial_transparency = config.get_value("pet", "initial_transparency", 0.5)
	pet_scale = config.get_value("pet", "scale", 1.0)
	current_material = config.get_value("pet", "current_material", 1)
	
	pet_initial_transparency = max(0.0, min(1.0, pet_initial_transparency))
	pet_scale = max(0.1, min(5.0, pet_scale))

func _read_window_section():
	window_initial_x = config.get_value("window", "initial_x", -1)
	window_initial_y = config.get_value("window", "initial_y", -1)
	window_always_on_top = config.get_value("window", "always_on_top", true)

func apply_material_preset():
	var preset = load_preset(current_material)
	glass_color = preset.get("glass_color", Color(0.1, 0.2, 0.4, 0.4))
	edge_glow = preset.get("edge_glow", 0.7)
	highlight_intensity = preset.get("highlight_intensity", 0.9)
	liquid_wobble = preset.get("liquid_wobble", 0.2)
	wobble_speed = preset.get("wobble_speed", 2.0)
	frost_intensity = preset.get("frost_intensity", 0.7)
	noise_scale = preset.get("noise_scale", 0.5)

func load_preset(material_id: int) -> Dictionary:
	var preset_paths = [
		"res://resources/presets/liquid_glass.cfg",
		"res://resources/presets/frosted_glass.cfg",
		"res://resources/presets/crystal_glass.cfg",
		"res://resources/presets/aurora_glass.cfg"
	]
	
	var index = clamp(material_id - 1, 0, 3)
	var path = preset_paths[index]
	
	var cfg = ConfigFile.new()
	var err = cfg.load(path)
	
	if err != OK:
		print("[材质] 加载预设失败: ", path)
		return get_default_preset()
	
	return {
		"name": cfg.get_value("preset", "name", "未知材质"),
		"glass_color": Color(
			cfg.get_value("preset", "glass_color_r", 0.5),
			cfg.get_value("preset", "glass_color_g", 0.5),
			cfg.get_value("preset", "glass_color_b", 0.5),
			cfg.get_value("preset", "glass_color_a", 0.5)
		),
		"edge_glow": cfg.get_value("preset", "edge_glow", 0.5),
		"highlight_intensity": cfg.get_value("preset", "highlight_intensity", 0.8),
		"liquid_wobble": cfg.get_value("preset", "liquid_wobble", 0.2),
		"wobble_speed": cfg.get_value("preset", "wobble_speed", 1.0),
		"frost_intensity": cfg.get_value("preset", "frost_intensity", 0.7),
		"noise_scale": cfg.get_value("preset", "noise_scale", 0.5)
	}

func get_default_preset() -> Dictionary:
	return {
		"name": "默认材质",
		"glass_color": Color(0.5, 0.5, 0.5, 0.5),
		"edge_glow": 0.5,
		"highlight_intensity": 0.8,
		"liquid_wobble": 0.2,
		"wobble_speed": 1.0,
		"frost_intensity": 0.7,
		"noise_scale": 0.5
	}

func _save_config():
	config.set_value("pet", "initial_transparency", pet_initial_transparency)
	config.set_value("pet", "scale", pet_scale)
	config.set_value("pet", "current_material", current_material)
	
	config.set_value("window", "initial_x", window_initial_x)
	config.set_value("window", "initial_y", window_initial_y)
	config.set_value("window", "always_on_top", window_always_on_top)
	
	DirAccess.make_dir_recursive_absolute("res://config")
	
	var err = config.save(config_path)
	if err == OK:
		print("✅ [配置] 配置文件已保存: ", config_path)
	else:
		print("❌ [配置] 配置文件保存失败")

func save_config():
	_save_config()

func print_config():
	print("\n📋 [配置] 当前配置参数:")
	print("├── [pet]")
	print("│   ├── initial_transparency: ", pet_initial_transparency)
	print("│   ├── scale: ", pet_scale)
	print("│   ├── current_material: ", current_material, " (", get_material_name(), ")")
	print("│   ├── glass_color: ", glass_color)
	print("│   ├── edge_glow: ", edge_glow)
	print("│   ├── highlight_intensity: ", highlight_intensity)
	print("│   ├── liquid_wobble: ", liquid_wobble)
	print("│   └── wobble_speed: ", wobble_speed)
	print("└── [window]")
	print("    ├── initial_x: ", window_initial_x)
	print("    ├── initial_y: ", window_initial_y)
	print("    └── always_on_top: ", window_always_on_top)
	print()

func get_material_name() -> String:
	var names = ["液态玻璃", "毛玻璃", "水晶玻璃", "极光玻璃"]
	if current_material >= 1 and current_material <= 4:
		return names[current_material - 1]
	return "未知材质"
