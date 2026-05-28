extends Node

var _base_path: String:
	get:
		if OS.has_feature("editor") or OS.has_feature("debug"):
			return ProjectSettings.globalize_path("res://../export/")
		else:
			return ProjectSettings.globalize_path("user://config/")

var _default_configs: Dictionary = {}
var _user_configs: Dictionary = {}

## 加载指定模块的默认配置和用户配置
func load_defaults(module_name: String):
	if module_name in _default_configs:
		return

	var cfg = ConfigFile.new()
	var err = cfg.load("res://config/%s.cfg" % module_name)
	if err != OK:
		push_error("[Config] Failed to load defaults: res://config/%s.cfg" % module_name)
		return
	_default_configs[module_name] = cfg

	var user_cfg = ConfigFile.new()
	var user_path = _base_path + module_name + ".cfg"
	if FileAccess.file_exists(user_path):
		user_cfg.load(user_path)
	_user_configs[module_name] = user_cfg

## 获取配置值
func cfg_get(section: String, key: String, default_value):
	for cfg in _user_configs.values():
		if cfg.has_section_key(section, key):
			return cfg.get_value(section, key, default_value)
	for cfg in _default_configs.values():
		if cfg.has_section_key(section, key):
			return cfg.get_value(section, key, default_value)
	return default_value

## 设置配置值：只存与默认不同的值
func cfg_set(section: String, key: String, value):
	var user_cfg = _find_user_config(section)
	if not user_cfg:
		return

	var default_val = _find_default(section, key)
	if default_val != null:
		if typeof(value) == TYPE_FLOAT and typeof(default_val) == TYPE_FLOAT:
			if is_equal_approx(value, default_val):
				user_cfg.erase_section_key(section, key)
				return
		elif value == default_val:
			user_cfg.erase_section_key(section, key)
			return
	user_cfg.set_value(section, key, value)

## 找到 section 属于哪个模块，返回其用户配置
func _find_user_config(section: String) -> ConfigFile:
	for module_name in _default_configs:
		if _default_configs[module_name].has_section(section):
			return _user_configs.get(module_name)
	return null

## 查找默认值
func _find_default(section: String, key: String):
	for cfg in _default_configs.values():
		if cfg.has_section_key(section, key):
			return cfg.get_value(section, key)
	return null

## 保存所有模块的用户配置
func save_config():
	if not DirAccess.dir_exists_absolute(_base_path):
		DirAccess.make_dir_recursive_absolute(_base_path)

	for module_name in _user_configs:
		var path = _base_path + module_name + ".cfg"
		var err = _user_configs[module_name].save(path)
		if err != OK:
			push_error("[Config] Failed to save: ", path)
