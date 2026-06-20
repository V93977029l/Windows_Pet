extends BasePetWindow

const PetConsts = preload("res://modules/pet/scripts/pet_constants.gd")

var _update_guard: UIUtils.UIUpdateGuard = UIUtils.UIUpdateGuard.new()

@onready var scale_slider: HSlider = $Background/MainHBox/CenterVBox/Scale/HBox2/Slider2
@onready var scale_input: LineEdit = $Background/MainHBox/CenterVBox/Scale/HBox2/Input2
@onready var apply_scale_btn: Button = $Background/MainHBox/CenterVBox/Scale/ApplyScaleBtn
@onready var material_combo: OptionButton = $Background/MainHBox/CenterVBox/Material/Combo
@onready var breathing_check: CheckButton = $Background/MainHBox/CenterVBox/DynamicEffect/BreathingCheck
@onready var motion_check: CheckButton = $Background/MainHBox/CenterVBox/DynamicEffect/MotionCheck
@onready var always_on_top_check: CheckButton = $Background/MainHBox/CenterVBox/AlwaysOnTop/Check
@onready var autostart_check: CheckButton = $Background/MainHBox/CenterVBox/AutoStart/Check
@onready var save_button: Button = $Background/MainHBox/CenterVBox/Buttons/Save
@onready var reset_button: Button = $Background/MainHBox/CenterVBox/Buttons/Reset
@onready var throw_btn: Button = $Background/MainHBox/CenterVBox/ThrowBtn


func _setup_ui():
	title = "桌宠设置 [调试用]"
	setup_material_combo()
	setup_connections()
	load_config()


func setup_connections():
	scale_slider.value_changed.connect(_on_scale_slider_changed)
	scale_input.text_changed.connect(_on_scale_input_changed)
	apply_scale_btn.pressed.connect(_on_apply_scale)
	material_combo.item_selected.connect(_on_material_changed)
	breathing_check.toggled.connect(_on_breathing_changed)
	motion_check.toggled.connect(_on_motion_changed)
	always_on_top_check.toggled.connect(_on_always_on_top_changed)
	autostart_check.toggled.connect(_on_autostart_changed)
	save_button.pressed.connect(_on_save)
	reset_button.pressed.connect(_on_reset)
	throw_btn.pressed.connect(_on_throw_settings)


func setup_material_combo():
	if not pet_node:
		return

	material_combo.clear()

	var presets = pet_node.get_all_presets()

	for i in range(presets.size()):
		var preset = presets[i]
		material_combo.add_item(preset.name)

	_select_current_material()
	material_combo.disabled = false


func load_config():
	_update_guard.try_lock()

	scale_slider.value = clamp(ConfigManager.cfg_get("pet", "pet_scale", PetConsts.PET_SCALE_DEFAULT), ProjectConstants.PET_SCALE_MIN, ProjectConstants.PET_SCALE_MAX)
	scale_input.text = NumberUtils.format_float(ConfigManager.cfg_get("pet", "pet_scale", PetConsts.PET_SCALE_DEFAULT))

	_select_current_material()

	breathing_check.button_pressed = true
	motion_check.button_pressed = true
	always_on_top_check.button_pressed = ConfigManager.cfg_get("window", "window_always_on_top", PetConsts.WINDOW_ALWAYS_ON_TOP_DEFAULT)
	autostart_check.button_pressed = _check_autostart_status()

	_update_guard.unlock()


func _select_current_material():
	var presets = pet_node.get_all_presets()
	var current_material_id: String = ConfigManager.cfg_get("pet", "slime_1_material", "slime_1")

	for i in range(presets.size()):
		var preset = presets[i]
		if preset.id == current_material_id:
			material_combo.select(i)
			return

	material_combo.select(0)


func _on_scale_slider_changed(value: float):
	if _update_guard.is_guarded():
		return

	var rounded = clamp(value, ProjectConstants.PET_SCALE_MIN, ProjectConstants.PET_SCALE_MAX)
	_update_guard.try_lock()
	scale_input.text = NumberUtils.format_float(rounded)
	_update_guard.unlock()

	ConfigManager.cfg_set("pet", "pet_scale", rounded)


func _on_scale_input_changed(text: String):
	if _update_guard.is_guarded():
		return

	var current_scale = ConfigManager.cfg_get("pet", "pet_scale", PetConsts.PET_SCALE_DEFAULT)
	if not text.is_valid_float():
		scale_input.text = NumberUtils.format_float(current_scale)
		return

	var value = text.to_float()
	if value < ProjectConstants.PET_SCALE_MIN or value > ProjectConstants.PET_SCALE_MAX:
		scale_input.text = NumberUtils.format_float(current_scale)
		return

	_update_guard.try_lock()
	scale_slider.value = value
	_update_guard.unlock()

	ConfigManager.cfg_set("pet", "pet_scale", value)


func _on_apply_scale():
	var value = ConfigManager.cfg_get("pet", "pet_scale", 1.0)
	EventBus.publish("pet_scale_apply", {"scale": value})
	print("✅ [设置] 缩放已应用: ", value)


func _on_material_changed(index: int):
	if _update_guard.is_guarded():
		return

	var presets = pet_node.get_all_presets()

	if index < presets.size():
		var preset = presets[index]
		ConfigManager.cfg_set("pet", "slime_1_material", preset.id)
		EventBus.publish("pet_material_changed", {"preset": preset, "preset_id": preset.id})
		print("✅ [设置] 材质已切换为: ", preset.name)


func _on_breathing_changed(enabled: bool):
	if _update_guard.is_guarded():
		return
	EventBus.publish("pet_breathing_toggled", {"enabled": enabled})


func _on_motion_changed(enabled: bool):
	if _update_guard.is_guarded():
		return
	EventBus.publish("pet_motion_effect_toggled", {"enabled": enabled})


func _on_always_on_top_changed(enabled: bool):
	if _update_guard.is_guarded():
		return
	ConfigManager.cfg_set("window", "window_always_on_top", enabled)
	EventBus.publish("window_always_on_top_changed", {"enabled": enabled})


func _on_autostart_changed(enabled: bool):
	if _update_guard.is_guarded():
		return

	if not _set_autostart(enabled):
		ConfigManager.cfg_set("window", "autostart_enabled", not enabled)
		_update_guard.try_lock()
		autostart_check.button_pressed = not enabled
		_update_guard.unlock()
		return

	ConfigManager.cfg_set("window", "autostart_enabled", enabled)
	print("✅ [设置] 开机自启动已", "启用" if enabled else "禁用")


func _get_exe_path() -> String:
	var exe_path = OS.get_executable_path()
	if exe_path.ends_with(".console.exe"):
		exe_path = exe_path.replace(".console.exe", ".exe")
	return exe_path


func _run_ps_script(ps_content: String, output: Array) -> int:
	var script_path = "user://autostart_temp.ps1"
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		printerr("[自启动] 无法写入临时脚本: ", script_path)
		return -1
	file.store_string(ps_content)
	file.close()

	var global_script_path = ProjectSettings.globalize_path(script_path)
	var args = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", global_script_path]
	var exit_code = OS.execute("powershell.exe", args, output, true, false)

	DirAccess.remove_absolute(global_script_path)

	return exit_code


func _set_autostart(enabled: bool) -> bool:
	if OS.has_feature("editor"):
		print("⚠️ [自启动] 编辑器模式下不支持注册表操作，请在导出后使用")
		return false

	var exe_path = _get_exe_path()
	var reg_key = ProjectConstants.REG_KEY
	var app_name = ProjectConstants.APP_NAME

	var ps_content: String
	if enabled:
		ps_content = 'Set-ItemProperty -Path "%s" -Name "%s" -Value "%s" -Force' % [reg_key, app_name, exe_path]
	else:
		ps_content = 'Remove-ItemProperty -Path "%s" -Name "%s" -ErrorAction SilentlyContinue' % [reg_key, app_name]

	var output = []
	var exit_code = _run_ps_script(ps_content, output)

	if exit_code == 0:
		print("✅ [自启动] 注册表", "添加" if enabled else "删除", "成功: ", exe_path)
		return true
	else:
		printerr("[自启动] 注册表操作失败, exit_code=", exit_code)
		for line in output:
			printerr("  ", line)
		return false


func _check_autostart_status() -> bool:
	if OS.has_feature("editor"):
		return false

	var exe_path = _get_exe_path()
	var reg_key = ProjectConstants.REG_KEY
	var app_name = ProjectConstants.APP_NAME

	var ps_content = 'Get-ItemProperty -Path "%s" -Name "%s" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "%s"' % [reg_key, app_name, app_name]

	var output = []
	var exit_code = _run_ps_script(ps_content, output)

	if exit_code == 0 and output.size() > 0:
		var reg_value = output[0].strip_edges()
		if reg_value == exe_path:
			return true

	return false


func _on_save():
	ConfigManager.save_config()
	EventBus.publish("settings_save_requested")
	print("✅ [设置] 配置已保存")


func _on_reset():
	ConfigManager.cfg_set("pet", "pet_scale", PetConsts.PET_SCALE_DEFAULT)
	ConfigManager.cfg_set("pet", "slime_1_material", "slime_1")
	ConfigManager.cfg_set("window", "window_always_on_top", PetConsts.WINDOW_ALWAYS_ON_TOP_DEFAULT)
	ConfigManager.cfg_set("window", "autostart_enabled", PetConsts.WINDOW_AUTOSTART_DEFAULT)
	load_config()
	_set_autostart(false)
	EventBus.publish("settings_reset_requested")
	print("✅ [设置] 已恢复默认配置")


func _on_throw_settings():
	var dialog_scene = load(ProjectConstants.THROW_DIALOG_SCENE)
	if dialog_scene:
		var dialog = dialog_scene.instantiate()
		get_tree().root.add_child(dialog)
		dialog.set_pet_node(pet_node)

		var window_pos = get_position()
		var window_size = get_size()
		dialog.position = Vector2i(window_pos.x + window_size.x + 10, window_pos.y)

		print("✅ [设置] 打开抛射参数设置弹窗")
