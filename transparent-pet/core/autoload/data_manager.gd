extends Node

var data_path: String:
	get:
		if OS.has_feature("editor") or OS.has_feature("debug"):
			return ProjectSettings.globalize_path("res://../export/savegame.json")
		else:
			return ProjectSettings.globalize_path("user://data/savegame.json")

var _data: Dictionary = {}

func _ready():
	load_data()

## 加载数据
func load_data():
	if not FileAccess.file_exists(data_path):
		return

	var file = FileAccess.open(data_path, FileAccess.READ)
	if not file:
		push_error("[Data] Failed to open: ", FileAccess.get_open_error())
		return

	var text = file.get_as_text()
	file.close()

	var parsed = JSON.new()
	var err = parsed.parse(text)
	if err != OK:
		push_error("[Data] Failed to parse: ", err)
		return

	_data = parsed.data as Dictionary

## 读取
func data_get(key: String, default):
	return _data.get(key, default)

## 写入
func data_set(key: String, value):
	_data[key] = value

## 保存
func save_data():
	var dir_path = data_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var temp = data_path + ".tmp"
	var file = FileAccess.open(temp, FileAccess.WRITE)
	if not file:
		push_error("[Data] Failed to open temp: ", FileAccess.get_open_error())
		return

	file.store_string(JSON.stringify(_data, "\t"))
	file.close()

	if FileAccess.file_exists(data_path):
		DirAccess.remove_absolute(data_path)
	DirAccess.rename_absolute(temp, data_path)
