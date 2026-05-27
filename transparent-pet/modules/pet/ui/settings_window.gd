## SettingsWindow - 设置窗口控制器 [调试用]
## =========================================================================
## 【架构定位】
##   此窗口仅用于开发调试，提供桌宠配置界面
##
## 【设计模式】
##   MVC - 此文件作为Controller，负责协调UI与数据
##
## 【核心职责】
##   1. 加载/保存配置
##   2. 应用用户设置
## =========================================================================

extends Window

## 桌宠主节点引用
var pet_node: Node2D = null

## 配置对象引用
var config = null

## =========================================================================
## @onready 变量
## =========================================================================

## 缩放滑块
@onready var scale_slider: HSlider = $Background/MainHBox/CenterVBox/Scale/HBox2/Slider2
## 缩放输入框
@onready var scale_input: LineEdit = $Background/MainHBox/CenterVBox/Scale/HBox2/Input2
## 应用缩放按钮
@onready var apply_scale_btn: Button = $Background/MainHBox/CenterVBox/Scale/ApplyScaleBtn
## 材质选择下拉框
@onready var material_combo: OptionButton = $Background/MainHBox/CenterVBox/Material/Combo
## 呼吸效果复选框（整体形变）
@onready var breathing_check: CheckButton = $Background/MainHBox/CenterVBox/DynamicEffect/BreathingCheck
## 动效复选框（材质扰动）
@onready var motion_check: CheckButton = $Background/MainHBox/CenterVBox/DynamicEffect/MotionCheck
## 窗口置顶复选框
@onready var always_on_top_check: CheckButton = $Background/MainHBox/CenterVBox/AlwaysOnTop/Check
## 开机自启动复选框
@onready var autostart_check: CheckButton = $Background/MainHBox/CenterVBox/AutoStart/Check
## 保存按钮
@onready var save_button: Button = $Background/MainHBox/CenterVBox/Buttons/Save
## 重置按钮
@onready var reset_button: Button = $Background/MainHBox/CenterVBox/Buttons/Reset

## 抛射参数设置按钮
@onready var throw_btn: Button = $Background/MainHBox/CenterVBox/ThrowBtn

## =========================================================================
## 成员变量
## =========================================================================

## UI更新保护标志（防止循环更新）
var _is_updating_ui: bool = false
## 是否有待处理的初始化
var _pending_setup: bool = false

## =========================================================================
## 初始化方法
## =========================================================================

## 设置主节点引用（延迟到_ready中初始化UI）
func set_pet_node(pet: Node2D):
	pet_node = pet
	if pet_node:
		config = pet_node.config
		_pending_setup = true

## 窗口就绪回调
func _ready():
	title = "桌宠设置 [调试用]"
	transparent = false
	always_on_top = true
	
	if _pending_setup:
		setup_material_combo()
		setup_connections()
		load_config()
		_pending_setup = false
	
	visible = true
	await get_tree().process_frame
	grab_focus()

## =========================================================================
## UI连接与初始化
## =========================================================================

## 绑定所有UI控件的信号处理器
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
	close_requested.connect(_on_close)

## 初始化材质选择下拉菜单
func setup_material_combo():
	if not pet_node or not pet_node.material_manager:
		return
	
	material_combo.clear()
	
	var registry = pet_node.material_manager.registry
	var presets = registry.get_all_presets()
	
	for i in range(presets.size()):
		var preset = presets[i]
		material_combo.add_item(preset.name)
	
	_select_current_material()
	material_combo.disabled = false

## =========================================================================
## 配置加载与同步
## =========================================================================

## 从配置对象加载设置到UI控件
func load_config():
	if not config:
		print("⚠️ [设置] 配置对象为空")
		return
	
	_is_updating_ui = true
	
	# 缩放是全局的
	scale_slider.value = clamp(config.pet_scale, 0.2, 4.0)
	scale_input.text = format_float(config.pet_scale)
	
	# 根据当前选中的史莱姆加载材质
	_select_current_material()
	
	# 其他全局设置
	breathing_check.button_pressed = true
	motion_check.button_pressed = true
	always_on_top_check.button_pressed = config.window_always_on_top
	autostart_check.button_pressed = _check_autostart_status()
	
	_is_updating_ui = false

## 在材质下拉菜单中选中当前使用的材质
func _select_current_material():
	var registry = pet_node.material_manager.registry
	var presets = registry.get_all_presets()
	
	var current_material_id: String = config.slime_1_material
	
	for i in range(presets.size()):
		var preset = presets[i]
		if preset.id == current_material_id:
			material_combo.select(i)
			return
	
	material_combo.select(0)

## 格式化浮点数为显示字符串（保留两位小数）
func format_float(value: float) -> String:
	return str(round(value * 100) / 100)

## =========================================================================
## 信号处理函数
## =========================================================================

## 缩放滑块值变化的处理
func _on_scale_slider_changed(value: float):
	if _is_updating_ui:
		return
	
	var rounded = clamp(value, 0.2, 4.0)
	_is_updating_ui = true
	scale_input.text = format_float(rounded)
	_is_updating_ui = false
	
	config.pet_scale = rounded

## 缩放输入框文字变化的处理
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

## "应用缩放"按钮点击的处理
func _on_apply_scale():
	var value = config.pet_scale
	apply_scale(value)
	apply_high_res_scale(value)
	print("✅ [设置] 缩放已应用: ", value)

## 材质下拉菜单选项变化的处理
func _on_material_changed(index: int):
	if _is_updating_ui:
		return
	
	var registry = pet_node.material_manager.registry
	var presets = registry.get_all_presets()
	
	if index < presets.size():
		var preset = presets[index]
		
		# 应用材质并保存配置
		pet_node.material_manager.apply_preset(preset)
		config.slime_1_material = preset.id

		# 通知主节点进行液态玻璃效果的创建/销毁
		pet_node.on_material_changed(preset.id)
		
		print("✅ [设置] 材质已切换为: ", preset.name)

## 呼吸复选框切换的处理
func _on_breathing_changed(enabled: bool):
	if _is_updating_ui:
		return
	if pet_node and pet_node.material_manager:
		pet_node.material_manager.set_breathing_enabled(enabled)

## 动效复选框切换的处理
func _on_motion_changed(enabled: bool):
	if _is_updating_ui:
		return
	if pet_node and pet_node.material_manager:
		pet_node.material_manager.set_motion_effect_enabled(enabled)

## 窗口置顶复选框切换的处理
func _on_always_on_top_changed(enabled: bool):
	if _is_updating_ui:
		return
	
	config.window_always_on_top = enabled
	apply_always_on_top(enabled)

## 开机自启动复选框切换的处理
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

## =========================================================================
## Windows自启动相关方法
## =========================================================================

## 获取可执行文件的路径
func _get_exe_path() -> String:
	var exe_path = OS.get_executable_path()
	if exe_path.ends_with(".console.exe"):
		exe_path = exe_path.replace(".console.exe", ".exe")
	return exe_path

## 执行PowerShell脚本
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

## 设置/取消Windows开机自启动
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

## 检查当前是否已设置为开机自启动
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

## =========================================================================
## 效果应用方法
## =========================================================================

## 应用缩放到桌宠精灵
func apply_scale(value: float):
	if not pet_node:
		print("⚠️ [设置] 无法应用缩放：pet_node 为空")
		return
	
	pet_node.update_pet_scale(value)

## 应用高清缩放
func apply_high_res_scale(value: float):
	if not pet_node:
		print("⚠️ [设置] 无法应用高分辨率缩放：pet_node 为空")
		return
	
	pet_node.apply_high_res_scale(value)

## 应用窗口置顶设置
func apply_always_on_top(enabled: bool):
	if not pet_node:
		print("⚠️ [设置] 无法设置窗口置顶：pet_node 为空")
		return
	
	var window = pet_node.get_window()
	window.always_on_top = enabled

## =========================================================================
## 按钮回调
## =========================================================================

## "保存配置"按钮的处理
func _on_save():
	if not config:
		print("⚠️ [设置] 无法保存配置：config 为空")
		return
	
	config.save_config()
	print("✅ [设置] 配置已保存")

## "恢复默认"按钮的处理
func _on_reset():
	config.pet_scale = 1.0
	config.slime_1_material = "slime_1"
	config.window_always_on_top = true
	config.autostart_enabled = false
	
	load_config()
	
	_set_autostart(false)
	
	apply_scale(config.pet_scale)
	if pet_node and pet_node.material_manager:
		pet_node.material_manager.set_breathing_enabled(true)
		pet_node.material_manager.set_motion_effect_enabled(true)
	apply_always_on_top(config.window_always_on_top)
	
	print("✅ [设置] 已恢复默认配置")

## 窗口关闭的处理
func _on_close():
	queue_free()


## 打开抛射参数设置弹窗
func _on_throw_settings():
	var dialog_scene = load("res://modules/pet/ui/throw_settings_dialog.tscn")
	if dialog_scene:
		var dialog = dialog_scene.instantiate()
		get_tree().root.add_child(dialog)
		dialog.set_pet_node(pet_node)

		var window_pos = get_position()
		var window_size = get_size()
		dialog.position = Vector2i(window_pos.x + window_size.x + 10, window_pos.y)

		print("✅ [设置] 打开抛射参数设置弹窗")
