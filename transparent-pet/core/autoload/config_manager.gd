extends Node

var user_config_path: String:
	get:
		if OS.has_feature("editor") or OS.has_feature("debug"):
			return ProjectSettings.globalize_path("res://../export/pet_config.cfg")
		else:
			return ProjectSettings.globalize_path("user://pet_config.cfg")

var _default_configs: Dictionary = {}
var _user_config: ConfigFile

func _ready():
	load_config()

## 加载用户配置
func load_config():
	_user_config = ConfigFile.new()
	if FileAccess.file_exists(user_config_path):
		var err = _user_config.load(user_config_path)
		if err != OK:
			push_warning("[Config] Failed to load user config: ", err)
	print("[Config] Loaded config")

## 加载指定模块的默认配置文件
func load_defaults(module_name: String):
	if module_name in _default_configs:
		return
	var cfg = ConfigFile.new()
	var path = "res://config/%s.cfg" % module_name
	var err = cfg.load(path)
	if err != OK:
		push_error("[Config] Failed to load defaults: ", path)
		return
	_default_configs[module_name] = cfg
	print("[Config] Loaded defaults: ", module_name)

## 获取配置值
func cfg_get(section: String, key: String, default_value):
	if _user_config.has_section_key(section, key):
		return _user_config.get_value(section, key, default_value)
	for cfg in _default_configs.values():
		if cfg.has_section_key(section, key):
			return cfg.get_value(section, key, default_value)
	return default_value

## 设置配置值：只存与默认不同的值
func cfg_set(section: String, key: String, value):
	var default_val = _find_default(section, key)
	if default_val != null:
		if typeof(value) == TYPE_FLOAT and typeof(default_val) == TYPE_FLOAT:
			if is_equal_approx(value, default_val):
				_user_config.erase_section_key(section, key)
				return
		elif value == default_val:
			_user_config.erase_section_key(section, key)
			return
	_user_config.set_value(section, key, value)

## 查找默认值
func _find_default(section: String, key: String):
	for cfg in _default_configs.values():
		if cfg.has_section_key(section, key):
			return cfg.get_value(section, key)
	return null

## 保存用户配置
func save_config():
	var dir_path = user_config_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var err = _user_config.save(user_config_path)
	if err == OK:
		print("[Config] Saved user config to: ", user_config_path)
	else:
		push_error("[Config] Failed to save user config: ", err)
