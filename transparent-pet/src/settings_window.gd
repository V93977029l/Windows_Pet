extends Window

var pet_node: Node2D = null
var config = null

@onready var scale_slider: HSlider = $Background/MainHBox/CenterVBox/Scale/HBox2/Slider2
@onready var scale_input: LineEdit = $Background/MainHBox/CenterVBox/Scale/HBox2/Input2
@onready var apply_scale_btn: Button = $Background/MainHBox/CenterVBox/Scale/ApplyScaleBtn
@onready var material_combo: OptionButton = $Background/MainHBox/CenterVBox/Material/Combo
@onready var dynamic_check: CheckButton = $Background/MainHBox/CenterVBox/DynamicEffect/Check
@onready var always_on_top_check: CheckButton = $Background/MainHBox/CenterVBox/AlwaysOnTop/Check
@onready var autostart_check: CheckButton = $Background/MainHBox/CenterVBox/AutoStart/Check
@onready var save_button: Button = $Background/MainHBox/CenterVBox/Buttons/Save
@onready var reset_button: Button = $Background/MainHBox/CenterVBox/Buttons/Reset

var _is_updating_ui: bool = false

func set_pet_node(pet: Node2D):
	pet_node = pet
	if pet_node:
		config = pet_node.config
		setup_material_combo()
		load_config()

func _ready():
	title = "桌宠设置"
	transparent = false
	always_on_top = true
	
	setup_connections()
	
	visible = true
	await get_tree().process_frame
	grab_focus()

func setup_connections():
	scale_slider.value_changed.connect(_on_scale_slider_changed)
	scale_input.text_changed.connect(_on_scale_input_changed)
	apply_scale_btn.pressed.connect(_on_apply_scale)
	material_combo.item_selected.connect(_on_material_changed)
	dynamic_check.toggled.connect(_on_dynamic_changed)
	always_on_top_check.toggled.connect(_on_always_on_top_changed)
	autostart_check.toggled.connect(_on_autostart_changed)
	save_button.pressed.connect(_on_save)
	reset_button.pressed.connect(_on_reset)
	close_requested.connect(_on_close)

func setup_material_combo():
	if not pet_node or not pet_node.material_manager:
		return
	
	material_combo.clear()
	
	var registry = pet_node.material_manager.registry
	var presets = registry.get_all_presets()
	
	var current_material_name = pet_node.get_current_material_name()
	var selected_index = 0
	
	for i in range(presets.size()):
		var preset = presets[i]
		material_combo.add_item(preset.name)
		if preset.name == current_material_name:
			selected_index = i
	
	material_combo.select(selected_index)
	material_combo.disabled = false

func load_config():
	if not config:
		print("⚠️ [设置] 配置对象为空")
		return
	
	_is_updating_ui = true
	
	scale_slider.value = clamp(config.pet_scale, 0.2, 4.0)
	scale_input.text = format_float(config.pet_scale)
	
	_select_current_material()
	dynamic_check.button_pressed = _get_enable_dynamic()
	always_on_top_check.button_pressed = config.window_always_on_top
	autostart_check.button_pressed = _check_autostart_status()
	
	_is_updating_ui = false

func _get_enable_dynamic() -> bool:
	return true

func _select_current_material():
	var registry = pet_node.material_manager.registry
	var presets = registry.get_all_presets()
	
	for i in range(presets.size()):
		var preset = presets[i]
		if preset.id == config.material_preset:
			material_combo.select(i)
			return
	
	material_combo.select(0)

func format_float(value: float) -> String:
	return str(round(value * 100) / 100)

func _on_scale_slider_changed(value: float):
	if _is_updating_ui:
		return
	
	var rounded = clamp(value, 0.2, 4.0)
	_is_updating_ui = true
	scale_input.text = format_float(rounded)
	_is_updating_ui = false
	
	config.pet_scale = rounded

func _on_scale_input_changed(text: String):
	if _is_updating_ui:
		return
	
	if not text.is_valid_float():
		scale_input.text = format_float(config.pet_scale)
		return
	
	var value = text.to_float()
	if value < 0.2 or value > 4.0:
		scale_input.text = format_float(config.pet_scale)
		return
	
	_is_updating_ui = true
	scale_slider.value = value
	_is_updating_ui = false
	
	config.pet_scale = value

func _on_apply_scale():
	var value = config.pet_scale
	apply_scale(value)
	apply_high_res_scale(value)
	print("✅ [设置] 缩放已应用: ", value)

func _on_material_changed(index: int):
	if _is_updating_ui:
		return
	
	var registry = pet_node.material_manager.registry
	var presets = registry.get_all_presets()
	
	if index < presets.size():
		var preset = presets[index]
		pet_node.material_manager.apply_preset(preset)
		config.material_preset = preset.id
		print("✅ [设置] 材质已切换为: ", preset.name)

func _on_dynamic_changed(enabled: bool):
	if _is_updating_ui:
		return
	
	apply_dynamic_effect(enabled)

func _on_always_on_top_changed(enabled: bool):
	if _is_updating_ui:
		return
	
	config.window_always_on_top = enabled
	apply_always_on_top(enabled)

func _on_autostart_changed(enabled: bool):
	if _is_updating_ui:
		return
	
	if not _set_autostart(enabled):
		config.autostart_enabled = not enabled
		_is_updating_ui = true
		autostart_check.button_pressed = not enabled
		_is_updating_ui = false
		return
	
	config.autostart_enabled = enabled
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
	var reg_key = "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
	var app_name = "TransparentPet"
	
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
	var reg_key = "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
	var app_name = "TransparentPet"
	
	var ps_content = 'Get-ItemProperty -Path "%s" -Name "%s" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "%s"' % [reg_key, app_name, app_name]
	
	var output = []
	var exit_code = _run_ps_script(ps_content, output)
	
	if exit_code == 0 and output.size() > 0:
		var reg_value = output[0].strip_edges()
		if reg_value == exe_path:
			return true
	
	return false

func apply_scale(value: float):
	if not pet_node:
		print("⚠️ [设置] 无法应用缩放：pet_node 为空")
		return
	
	pet_node.update_pet_scale(value)

func apply_high_res_scale(value: float):
	if not pet_node:
		print("⚠️ [设置] 无法应用高分辨率缩放：pet_node 为空")
		return
	
	pet_node.apply_high_res_scale(value)

func apply_dynamic_effect(enabled: bool):
	if not pet_node:
		print("⚠️ [设置] 无法设置动态效果：pet_node 为空")
		return
	
	pet_node.material_manager.set_dynamic_enabled(enabled)

func apply_always_on_top(enabled: bool):
	if not pet_node:
		print("⚠️ [设置] 无法设置窗口置顶：pet_node 为空")
		return
	
	var window = pet_node.get_window()
	window.always_on_top = enabled

func _on_save():
	if not config:
		print("⚠️ [设置] 无法保存配置：config 为空")
		return
	
	config.save_config()
	print("✅ [设置] 配置已保存")

func _on_reset():
	config.pet_scale = 1.0
	config.window_always_on_top = true
	config.autostart_enabled = false
	
	load_config()
	
	_set_autostart(false)
	
	apply_scale(config.pet_scale)
	apply_dynamic_effect(true)
	apply_always_on_top(config.window_always_on_top)
	
	print("✅ [设置] 已恢复默认配置")

func _on_close():
	queue_free()