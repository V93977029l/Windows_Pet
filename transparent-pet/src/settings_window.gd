## SettingsWindow - 设置窗口控制器
## =========================================================================
## 【架构定位】
##   本类是桌宠设置界面的控制器，继承自Godot的 Window 类，
##   提供了一个独立的浮动设置面板，用户可以用它来调整桌宠的
##   各种参数（缩放、材质、置顶、自启动等）。
##
## 【设计模式】
##   采用"MVC模式"的变形——Window作为视图（View）、本GDScript
##   作为控制器（Controller）、pet_config.gd 作为数据模型（Model）。
##   设置窗口不直接操作UI效果的底层实现，而是通过调用主节点的方法
##   （如 apply_scale(), apply_dynamic_effect() 等）间接完成。
##
## 【核心职责】
##   1. UI控件的初始化与信号绑定
##   2. 配置数据的加载与UI同步
##   3. 用户交互的响应与配置更新
##   4. Windows开机自启动的注册表操作（仅Windows平台）
##
## 【UI结构】（参照场景文件中的节点树）
##   Background/MainHBox/CenterVBox/
##     ├── Scale/           — 缩放调节（滑块+输入框+应用按钮）
##     ├── Material/        — 材质选择（下拉菜单）
##     ├── DynamicEffect/   — 动态效果开关（复选框）
##     ├── AlwaysOnTop/     — 窗口置顶开关（复选框）
##     ├── AutoStart/       — 开机自启动开关（复选框）
##     └── Buttons/         — 保存/重置按钮
##
## 【_is_updating_ui 标志说明】
##   这是防止UI更新循环的关键标志。当代码修改UI控件值时，
##   会触发控件的信号（如 value_changed），而信号的响应函数
##   又会尝试修改其他控件——如果不加防护，会形成无限循环。
##   _is_updating_ui=true 时跳过所有信号处理，只做数据更新。
## =========================================================================

extends Window

## 桌宠主节点的引用（Node2D）
## 用于调用主节点上的各种操作方法（缩放、材质切换等）
var pet_node: Node2D = null

## 配置对象的引用（pet_config.gd的实例）
## 用于读写配置参数，用户的所有设置都会同步到此对象
var config = null

## =========================================================================
## @onready 变量 —— 在 _ready() 时延迟初始化的UI控件引用
## =========================================================================
## 使用 @onready 而不是在 _init() 中获取，是因为在 _init() 阶段
## 场景树尚未构建完成，$ 语法无法访问子节点

## 缩放滑块（HSlider）—— 允许用户在 0.2 ~ 4.0 之间拖动调整
@onready var scale_slider: HSlider = $Background/MainHBox/CenterVBox/Scale/HBox2/Slider2

## 缩放数值输入框（LineEdit）—— 允许用户直接输入精确数值
@onready var scale_input: LineEdit = $Background/MainHBox/CenterVBox/Scale/HBox2/Input2

## 应用缩放按钮 —— 点击后将当前缩放值真正应用到桌宠精灵
@onready var apply_scale_btn: Button = $Background/MainHBox/CenterVBox/Scale/ApplyScaleBtn

## 材质选择下拉框（OptionButton）—— 列出所有可用材质预设
@onready var material_combo: OptionButton = $Background/MainHBox/CenterVBox/Material/Combo

## 动态效果复选框（CheckButton）—— 开关Shader中的动态动画
@onready var dynamic_check: CheckButton = $Background/MainHBox/CenterVBox/DynamicEffect/Check

## 窗口置顶复选框 —— 控制窗口是否始终在最上层
@onready var always_on_top_check: CheckButton = $Background/MainHBox/CenterVBox/AlwaysOnTop/Check

## 开机自启动复选框 —— 控制是否向Windows注册表添加启动项
@onready var autostart_check: CheckButton = $Background/MainHBox/CenterVBox/AutoStart/Check

## 保存按钮 —— 将当前配置持久化到文件
@onready var save_button: Button = $Background/MainHBox/CenterVBox/Buttons/Save

## 重置按钮 —— 恢复所有设置为默认值
@onready var reset_button: Button = $Background/MainHBox/CenterVBox/Buttons/Reset


## =========================================================================
## 成员变量
## =========================================================================

## UI更新保护标志（防止循环更新）
## true: 正在通过代码更新UI控件 → 跳过所有信号处理
## false: 正常状态，响应用户交互
var _is_updating_ui: bool = false


## 设置主节点引用并初始化UI
## 【参数】
##   pet: Node2D - 桌宠主节点（通常是main.gd的根节点）
## 【核心逻辑】
##   1. 保存 pet_node 引用
##   2. 从 pet_node 获取 config 对象引用
##   3. 初始化材质下拉菜单（填充预设列表）
##   4. 从配置文件加载当前值到UI控件
## 【调用时机】由主节点在创建设置窗口后调用
func set_pet_node(pet: Node2D):
	pet_node = pet
	if pet_node:
		config = pet_node.config
		setup_material_combo()
		load_config()


## 窗口就绪回调（Godot生命周期方法）
## 【核心逻辑】
##   1. 设置窗口标题为"桌宠设置"
##   2. 关闭窗口自身的透明效果（设置面板不需要透明）
##   3. 启用置顶（设置窗口应始终可见）
##   4. 绑定所有UI控件的信号
##   5. 显式设置窗口可见
##   6. 等待一帧后获取焦点（确保窗口完全加载后再获取焦点）
## 【为什么 await get_tree().process_frame？】
##   在某些平台下，窗口创建后立即 grab_focus() 可能失败。
##   等待一帧确保窗口系统已完成所有初始化。
func _ready():
	title = "桌宠设置"
	transparent = false
	always_on_top = true
	
	setup_connections()
	
	visible = true
	await get_tree().process_frame
	grab_focus()


## 绑定所有UI控件的信号处理器
## 【核心逻辑】
##   将每个UI控件的事件信号连接到对应的处理函数。
##   这是Godot的"信号-槽"机制的标准用法。
## 【绑定的信号】
##   - 滑块值变化 → 同步更新输入框
##   - 输入框文字变化 → 同步更新滑块
##   - 各种按钮点击 → 执行对应操作
##   - 复选框切换 → 应用对应设置
##   - 窗口关闭 → 释放窗口节点
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


## 初始化材质选择下拉菜单
## 【核心逻辑】
##   1. 从 pet_node 的 material_manager 获取材质注册表
##   2. 遍历所有已注册的材质预设
##   3. 将每个预设的 name 添加为下拉菜单选项
##   4. 根据当前使用的材质名称选中对应项
## 【边界情况】
##   - pet_node 或 material_manager 为 null → 直接返回
##   - 没有任何预设 → 下拉菜单保持空白（但注册表至少有一个默认预设）
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


## 从配置对象加载设置到UI控件
## 【核心逻辑】
##   1. 开启 _is_updating_ui 保护标志
##   2. 将 config 中的各项参数同步到对应的UI控件
##   3. 关闭 _is_updating_ui 保护标志
## 【为什么需要 _is_updating_ui？】
##   设置UI控件值时会触发它们的 changed/toggled 信号，
##   这些信号的处理函数会再次尝试修改 config —— 形成循环。
##   _is_updating_ui 告诉信号处理器"这是代码触发的，不要响应"。
## 【边界情况】
##   - config 为 null → 打印警告并返回
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


## 获取动态效果的启用状态
## 【返回值】 bool - 当前是否启用动态效果
## 【当前实现】始终返回 true
## 【扩展点】将来可以从 Shader 参数或配置读取实际状态
func _get_enable_dynamic() -> bool:
	return true


## 在材质下拉菜单中选中当前使用的材质
## 【核心逻辑】
##   遍历注册表中的所有预设，找到 id 与 config.material_preset
##   匹配的项，设置为下拉菜单的当前选中项。
## 【边界情况】
##   如果没有匹配的预设（如配置文件中的id已过时）→ 选中第0项
func _select_current_material():
	var registry = pet_node.material_manager.registry
	var presets = registry.get_all_presets()
	
	for i in range(presets.size()):
		var preset = presets[i]
		if preset.id == config.material_preset:
			material_combo.select(i)
			return
	
	material_combo.select(0)


## 格式化浮点数为显示字符串（保留两位小数）
## 【参数】
##   value: float - 要格式化的浮点数
## 【返回值】 String - 格式化的字符串，如 "1.50"
## 【核心逻辑】 round(value * 100) / 100 → 保留两位小数
## 【用途】用于缩放输入框的显示文本
func format_float(value: float) -> String:
	return str(round(value * 100) / 100)


## =========================================================================
## 信号处理函数
## =========================================================================

## 缩放滑块值变化的处理
## 【参数】
##   value: float - 滑块当前值
## 【核心逻辑】
##   - 如果正在更新UI（_is_updating_ui）→ 跳过
##   - 将值钳制到 [0.2, 4.0] 范围
##   - 同步更新缩放输入框的文本
##   - 直接更新 config.pet_scale（实时生效，无需点击"应用"）
func _on_scale_slider_changed(value: float):
	if _is_updating_ui:
		return
	
	var rounded = clamp(value, 0.2, 4.0)
	_is_updating_ui = true
	scale_input.text = format_float(rounded)
	_is_updating_ui = false
	
	config.pet_scale = rounded


## 缩放输入框文字变化的处理
## 【参数】
##   text: String - 输入框的当前文本
## 【核心逻辑】
##   - 如果正在更新UI → 跳过
##   - 验证输入是否为合法浮点数
##   - 验证值是否在 [0.2, 4.0] 范围内
##   - 同步更新滑块位置
##   - 更新 config.pet_scale
## 【边界情况】
##   - 输入不是合法数字 → 恢复为 config 中的当前值
##   - 输入超出范围 → 恢复为 config 中的当前值
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
## 【核心逻辑】
##   从 config 读取当前缩放值，调用 pet_node 的两个缩放方法：
##   1. apply_scale() — 普通缩放更新（快速）
##   2. apply_high_res_scale() — 高清重渲染（从SVG重新生成纹理）
## 【为什么需要两个方法？】
##   普通缩放只改 scale 属性，高清缩放会重新渲染纹理。
##   两者配合确保显示效果最佳。
func _on_apply_scale():
	var value = config.pet_scale
	apply_scale(value)
	apply_high_res_scale(value)
	print("✅ [设置] 缩放已应用: ", value)


## 材质下拉菜单选项变化的处理
## 【参数】
##   index: int - 选中的选项索引
## 【核心逻辑】
##   - 如果正在更新UI → 跳过
##   - 从注册表获取选中的预设
##   - 调用 material_manager.apply_preset() 应用材质
##   - 更新 config.material_preset 为预设的 id
## 【注意】索引越界保护：只在 index < presets.size() 时才处理
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


## 动态效果复选框切换的处理
## 【参数】
##   enabled: bool - 是否启用动态效果
## 【核心逻辑】
##   - 如果正在更新UI → 跳过
##   - 委托给 apply_dynamic_effect() 执行实际的Shader参数设置
func _on_dynamic_changed(enabled: bool):
	if _is_updating_ui:
		return
	
	apply_dynamic_effect(enabled)


## 窗口置顶复选框切换的处理
## 【参数】
##   enabled: bool - 是否置顶
## 【核心逻辑】
##   - 如果正在更新UI → 跳过
##   - 更新 config 中的置顶标志
##   - 委托给 apply_always_on_top() 执行实际的窗口属性设置
func _on_always_on_top_changed(enabled: bool):
	if _is_updating_ui:
		return
	
	config.window_always_on_top = enabled
	apply_always_on_top(enabled)


## 开机自启动复选框切换的处理
## 【参数】
##   enabled: bool - 是否启用开机自启动
## 【核心逻辑】
##   1. 如果正在更新UI → 跳过
##   2. 调用 _set_autostart() 尝试修改注册表
##   3. 如果修改失败 → 回滚UI状态（复选框恢复原值、config恢复原值）
##   4. 如果修改成功 → 更新 config.autostart_enabled
## 【为什么需要回滚机制？】
##   注册表操作可能因权限不足等原因失败。失败时必须恢复UI状态，
##   避免UI显示与实际状态不一致——这是"乐观更新+失败回滚"模式。
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
## 【返回值】 String - 当前运行的可执行文件完整路径
## 【核心逻辑】
##   从 OS.get_executable_path() 获取路径，并处理 Godot 的特殊命名：
##   Godot的调试运行会生成 .console.exe 后缀的文件，
##   但实际的发布版是 .exe 结尾，所以需要去除 .console 部分。
func _get_exe_path() -> String:
	var exe_path = OS.get_executable_path()
	if exe_path.ends_with(".console.exe"):
		exe_path = exe_path.replace(".console.exe", ".exe")
	return exe_path


## 执行PowerShell脚本（Windows注册表操作的底层方法）
## 【参数】
##   ps_content: String - PowerShell脚本内容
##   output: Array - 输出数组，用于接收脚本的标准输出
## 【返回值】 int - 进程退出码（0表示成功）
## 【核心逻辑】
##   1. 将脚本内容写入临时 .ps1 文件（user:// 目录）
##   2. 通过 OS.execute() 调用 PowerShell 执行该脚本
##      - -NoProfile: 不加载用户配置文件（更快）
##      - -ExecutionPolicy Bypass: 绕过执行策略限制
##      - -File: 指定要执行的脚本文件
##   3. 执行完毕后删除临时脚本文件
## 【为什么用临时文件而不是管道？】
##   OS.execute() 对复杂脚本的支持有限，写入文件更可靠。
##   同时避免了命令行参数过长或特殊字符转义的问题。
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
## 【参数】
##   enabled: bool - true为添加启动项，false为删除启动项
## 【返回值】 bool - true表示操作成功，false表示失败
## 【核心逻辑】
##   通过操作注册表 HKCU\Software\Microsoft\Windows\CurrentVersion\Run
##   来实现开机自启动。这是Windows标准的自启动注册表位置。
##   - 启用时：Set-ItemProperty 添加注册表项
##   - 禁用时：Remove-ItemProperty 删除注册表项（-ErrorAction SilentlyContinue 防止项不存在时报错）
## 【边界情况】
##   - 编辑器模式下 → 不支持注册表操作，返回 false
##   - 权限不足 → PowerShell返回非零退出码，返回 false
##   - 注册表项已存在/不存在 → PowerShell 的 -Force / -ErrorAction 处理
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
## 【返回值】 bool - true表示已设置自启动
## 【核心逻辑】
##   通过PowerShell查询注册表，比较注册表中的路径与当前EXE路径是否一致。
##   路径比较是必要的——如果用户移动了EXE位置，旧路径的自启动项
##   实际上已失效，应返回 false。
## 【边界情况】
##   - 编辑器模式下 → 直接返回 false
##   - 注册表项不存在 → PowerShell正常执行但无输出，返回 false
##   - 路径不匹配 → 返回 false（引导用户重新设置）
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
## 效果应用方法（委托给主节点的对应方法）
## =========================================================================

## 应用缩放到桌宠精灵
## 【参数】
##   value: float - 缩放倍率
## 【核心逻辑】委托给 pet_node.update_pet_scale()
## 【边界情况】pet_node 为空 → 打印警告并返回
func apply_scale(value: float):
	if not pet_node:
		print("⚠️ [设置] 无法应用缩放：pet_node 为空")
		return
	
	pet_node.update_pet_scale(value)


## 应用高清缩放（从SVG重新渲染）
## 【参数】
##   value: float - 缩放倍率
## 【核心逻辑】委托给 pet_node.apply_high_res_scale()
## 【边界情况】pet_node 为空 → 打印警告并返回
func apply_high_res_scale(value: float):
	if not pet_node:
		print("⚠️ [设置] 无法应用高分辨率缩放：pet_node 为空")
		return
	
	pet_node.apply_high_res_scale(value)


## 应用动态效果开关
## 【参数】
##   enabled: bool - 是否启用
## 【核心逻辑】委托给 pet_node.material_manager.set_dynamic_enabled()
## 【边界情况】pet_node 为空 → 打印警告并返回
func apply_dynamic_effect(enabled: bool):
	if not pet_node:
		print("⚠️ [设置] 无法设置动态效果：pet_node 为空")
		return
	
	pet_node.material_manager.set_dynamic_enabled(enabled)


## 应用窗口置顶设置
## 【参数】
##   enabled: bool - 是否置顶
## 【核心逻辑】
##   通过 pet_node 获取所属窗口，设置窗口的 always_on_top 属性。
##   Godot的 Window.always_on_top 会调用平台相关的API实现置顶。
## 【边界情况】pet_node 为空 → 打印警告并返回
func apply_always_on_top(enabled: bool):
	if not pet_node:
		print("⚠️ [设置] 无法设置窗口置顶：pet_node 为空")
		return
	
	var window = pet_node.get_window()
	window.always_on_top = enabled


## "保存配置"按钮的处理
## 【核心逻辑】调用 config.save_config() 持久化当前设置
## 【边界情况】config 为空 → 打印警告并返回
func _on_save():
	if not config:
		print("⚠️ [设置] 无法保存配置：config 为空")
		return
	
	config.save_config()
	print("✅ [设置] 配置已保存")


## "恢复默认"按钮的处理
## 【核心逻辑】
##   1. 重置 config 中的关键参数为默认值
##   2. 重新加载UI（将默认值反映到控件上）
##   3. 清除开机自启动注册表项
##   4. 应用默认缩放、动态效果、置顶设置
## 【注意】重置操作后配置不会自动保存，用户需要点击"保存"按钮
##   来持久化默认设置——这是"非破坏性"设计
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


## 窗口关闭的处理
## 【核心逻辑】调用 queue_free() 将窗口节点从场景树中移除并释放内存
## 【注意】使用 queue_free() 而不是 free()，因为此回调可能在
##   信号处理链中触发，queue_free() 是安全的延迟释放方式。
func _on_close():
	queue_free()
