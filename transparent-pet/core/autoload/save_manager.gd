extends Node

## ============================================================================
## core/autoload/save_manager.gd — 存档/读档服务
## ============================================================================
## 【架构定位】
##   本类负责游戏数据的持久化存储与读取。与 DataManager 不同，
##   SaveManager 面向"存档"概念，支持多存档槽位、元数据记录、
##   自动保存等功能。DataManager 则负责轻量级的键值对数据持久化。
##
## 【核心职责】
##   1. 多存档槽位管理（创建/删除/列表）
##   2. 存档的序列化与反序列化（JSON 格式）
##   3. 自动保存定时器
##   4. 存档元数据（创建时间、游戏版本、存档名称）
##
## 【存档文件路径】
##   编辑器模式: res://../export/saves/
##   导出模式: user://saves/
## ============================================================================

signal save_completed(slot_name: String)
signal load_completed(slot_name: String)
signal auto_save_triggered

const SAVES_DIR := "saves"
const META_FILE := "_meta.json"
const AUTOSAVE_SLOT := "autosave"

var _auto_save_timer: Timer
var _auto_save_interval: float = 60.0
var _auto_save_enabled: bool = false

var saves_path: String:
	get:
		if OS.has_feature("editor") or OS.has_feature("debug"):
			return ProjectSettings.globalize_path("res://../export/" + SAVES_DIR + "/")
		else:
			return ProjectSettings.globalize_path("user://" + SAVES_DIR + "/")

func _ready() -> void:
	_ensure_saves_dir()

func _ensure_saves_dir() -> void:
	if not DirAccess.dir_exists_absolute(saves_path):
		DirAccess.make_dir_recursive_absolute(saves_path)

func _get_slot_path(slot_name: String) -> String:
	return saves_path + slot_name + ".json"

func _get_meta_path() -> String:
	return saves_path + META_FILE

## 保存存档到指定槽位
## @param slot_name: 存档槽位名称
## @param data: 要保存的数据（Dictionary）
## @param display_name: 存档显示名称（可选，默认使用 slot_name）
func save_to_slot(slot_name: String, data: Dictionary, display_name: String = "") -> bool:
	_ensure_saves_dir()

	var save_data := {
		"version": ProjectSettings.get_setting("application/config/version", "0.0.0"),
		"timestamp": Time.get_unix_time_from_system(),
		"display_name": display_name if not display_name.is_empty() else slot_name,
		"data": data
	}

	var file := FileAccess.open(_get_slot_path(slot_name), FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] 无法写入存档: " + slot_name)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	_update_meta(slot_name, display_name)
	save_completed.emit(slot_name)
	return true

## 从指定槽位读取存档
## @param slot_name: 存档槽位名称
## @return: 存档数据 Dictionary，失败返回空 Dictionary
func load_from_slot(slot_name: String) -> Dictionary:
	var path := _get_slot_path(slot_name)
	if not FileAccess.file_exists(path):
		push_warning("[SaveManager] 存档不存在: " + slot_name)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[SaveManager] 无法读取存档: " + slot_name)
		return {}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("[SaveManager] 存档解析失败: " + slot_name)
		return {}

	var save_data: Dictionary = json.get_data()
	load_completed.emit(slot_name)
	return save_data.get("data", {})

## 获取存档的元数据（不含实际游戏数据）
func get_slot_meta(slot_name: String) -> Dictionary:
	var path := _get_slot_path(slot_name)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return {}

	var save_data: Dictionary = json.get_data()
	return {
		"version": save_data.get("version", ""),
		"timestamp": save_data.get("timestamp", 0),
		"display_name": save_data.get("display_name", slot_name)
	}

## 删除指定槽位的存档
func delete_slot(slot_name: String) -> bool:
	var path := _get_slot_path(slot_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		_remove_meta_entry(slot_name)
		return true
	return false

## 获取所有存档槽位列表
func list_slots() -> Array[String]:
	_ensure_saves_dir()
	var dir := DirAccess.open(saves_path)
	if not dir:
		return []

	var slots: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json") and file_name != META_FILE:
			slots.append(file_name.trim_suffix(".json"))
		file_name = dir.get_next()
	dir.list_dir_end()
	return slots

## 检查指定槽位是否存在
func slot_exists(slot_name: String) -> bool:
	return FileAccess.file_exists(_get_slot_path(slot_name))

## 启用自动保存
## @param interval: 自动保存间隔（秒），默认 60 秒
func enable_auto_save(interval: float = 60.0) -> void:
	_auto_save_interval = interval
	_auto_save_enabled = true

	if not _auto_save_timer:
		_auto_save_timer = Timer.new()
		_auto_save_timer.one_shot = false
		_auto_save_timer.autostart = false
		_auto_save_timer.timeout.connect(_on_auto_save_timeout)
		add_child(_auto_save_timer)

	_auto_save_timer.wait_time = _auto_save_interval
	_auto_save_timer.start()

## 禁用自动保存
func disable_auto_save() -> void:
	_auto_save_enabled = false
	if _auto_save_timer:
		_auto_save_timer.stop()

## 触一次自动保存（外部模块也可以调用）
func trigger_auto_save(data: Dictionary) -> bool:
	if not _auto_save_enabled:
		return false
	auto_save_triggered.emit()
	return save_to_slot(AUTOSAVE_SLOT, data, "自动存档")

func _on_auto_save_timeout() -> void:
	auto_save_triggered.emit()

func _update_meta(slot_name: String, display_name: String) -> void:
	var meta := _load_meta_file()
	meta[slot_name] = {
		"display_name": display_name if not display_name.is_empty() else slot_name,
		"timestamp": Time.get_unix_time_from_system()
	}
	_save_meta_file(meta)

func _remove_meta_entry(slot_name: String) -> void:
	var meta := _load_meta_file()
	meta.erase(slot_name)
	_save_meta_file(meta)

func _load_meta_file() -> Dictionary:
	var path := _get_meta_path()
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return {}

	return json.get_data()

func _save_meta_file(meta: Dictionary) -> void:
	var file := FileAccess.open(_get_meta_path(), FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(meta, "\t"))
	file.close()
