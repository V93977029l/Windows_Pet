## TrayManager - 系统托盘管理器
## =========================================================================
## 【架构定位】
##   本类负责Windows系统托盘（System Tray）的创建与管理，
##   是桌宠应用与操作系统交互的桥梁。它封装了GDExtension提供的
##   原生系统托盘功能，使得桌宠可以最小化到托盘区域，
##   并通过托盘图标提供右键菜单（退出）和左键交互（打开设置）。
##
## 【设计模式】
##   采用"门面模式"——将底层GDExtension的复杂调用封装为简洁的
##   高层API。外部只需调用 init() 即可，无需关心GDExtension的
##   加载、初始化等细节。同时使用"观察者模式"通过信号通知上层。
##
## 【核心职责】
##   1. 系统托盘的创建与初始化（含GDExtension的动态加载）
##   2. 托盘图标的设置（支持多路径回退查找）
##   3. 托盘交互事件的分发（通过信号 settings_requested / exit_requested）
##   4. 任务栏图标的隐藏（使应用看起来像纯托盘应用）
##
## 【信号说明】
##   - settings_requested: 用户左键点击托盘图标时发出，通常打开设置窗口
##   - exit_requested: 用户在托盘右键菜单中选择退出时发出，关闭应用
##
## 【GDExtension加载流程】
##   1. 先尝试 ClassDB.class_exists() 检测SystemTray类是否已注册
##   2. 若不存在，手动 preload() 加载GDExtension文件进行注册
##   3. 加载后再次检测，成功则创建托盘，失败则打印错误
## =========================================================================

class_name TrayManager
extends Node

## 用户左键点击托盘图标时发出的信号
## 通常连接到打开设置窗口的逻辑
signal settings_requested

## 用户在托盘右键菜单中选择"退出"时发出的信号
## 通常连接到关闭应用的逻辑
signal exit_requested

## SystemTray原生对象引用（来自GDExtension）
## 这是与操作系统交互的核心对象，所有的托盘操作都通过它完成
var system_tray = null

## 初始化托盘管理器（公共入口）
## 【参数】
##   _pet: Node2D - 桌宠主节点引用（当前未使用，预留扩展）
##     将来可能用于获取桌宠状态以更新托盘提示文字等
## 【核心逻辑】
##   直接委托给 init_system_tray() 执行实际的初始化流程
func init(_pet: Node2D):
	init_system_tray()


## 初始化系统托盘（核心初始化流程）
## 【核心逻辑】
##   分两个阶段尝试加载SystemTray类：
##   阶段1 — 直接检测：调用 ClassDB.class_exists() 判断类是否已注册
##           （如果GDExtension已由引擎自动加载，则类已可用）
##   阶段2 — 手动加载：如果类不存在，手动 load() GDExtension文件，
##           触发引擎注册SystemTray类，然后再次检测
## 【为什么需要手动加载GDExtension？】
##   Godot引擎有时不会自动加载所有GDExtension，特别是编辑器模式下。
##   手动 preload() 可以确保在任何环境下都能正确加载SystemTray。
## 【边界情况】
##   - GDExtension文件不存在 → 打印错误，system_tray保持null
##   - 加载成功但类仍未注册 → 打印错误（DLL可能缺失）
##   - 一切正常 → 调用 _create_tray() 创建原生托盘
func init_system_tray():
	print("🔧 [托盘] 开始初始化系统托盘...")
	
	if ClassDB.class_exists("SystemTray"):
		print("📋 [托盘] SystemTray 类存在，直接实例化")
		_create_tray()
	else:
		print("📋 [托盘] SystemTray 类不存在，尝试手动加载 GDExtension...")
		var gdext_path = "res://addons/system_tray/system_tray.gdextension"
		var gdext_file = load(gdext_path)
		if gdext_file:
			print("✅ [托盘] GDExtension 文件加载成功，重试检测...")
			if ClassDB.class_exists("SystemTray"):
				print("✅ [托盘] SystemTray 类已可用")
				_create_tray()
			else:
				print("❌ [托盘] 加载 GDExtension 后 SystemTray 类仍不可用")
				printerr("❌ [托盘] 系统托盘无法使用，请检查 DLL 是否存在")
		else:
			print("❌ [托盘] GDExtension 文件加载失败: " + gdext_path)
			printerr("❌ [托盘] 系统托盘无法使用")
	
	print("✅ [托盘] 托盘初始化完成")


## 创建原生系统托盘（内部方法）
## 【核心逻辑】
##   1. 通过 ClassDB.instantiate() 实例化SystemTray
##   2. 设置窗口标题（用于任务管理器中的标识）
##   3. 调用 create() 创建托盘图标（参数为提示文字）
##   4. 查找并设置.ico图标文件
##   5. 绑定左键点击和右键点击的回调函数
##   6. 显示托盘图标并隐藏任务栏图标
## 【为什么 hide_taskbar_icon()？】
##   桌宠作为"后台型"应用，通常不需要在任务栏中显示。
##   托盘模式是更友好的桌面应用表现形式。
## 【回调绑定方式】
##   使用 Callable(self, "method_name") 将GDScript方法绑定到
##   SystemTray的回调，实现原生代码到GDScript的事件传递。
## 【边界情况】
##   - SystemTray实例化失败 → 打印错误并返回
##   - 图标文件找不到 → 打印警告，使用系统默认图标
func _create_tray():
	system_tray = ClassDB.instantiate("SystemTray")
	if not system_tray:
		print("❌ [托盘] SystemTray 实例化失败")
		return
	
	system_tray.set_window_title(ProjectConstants.APP_NAME)
	system_tray.create("桌宠")
	
	var ico_path = _get_icon_path("res://core/services/app_icon.ico")
	if not ico_path.is_empty():
		system_tray.set_icon(ico_path)
	else:
		print("⚠️ [托盘] 图标文件不可用，使用默认图标")
	
	system_tray.set_left_click_callback(Callable(self, "_on_tray_left_click"))
	system_tray.set_right_click_callback(Callable(self, "_on_tray_menu_exit"))
	
	system_tray.show()
	system_tray.hide_taskbar_icon()
	
	print("✅ [托盘] 原生系统托盘已创建")


## 获取托盘图标文件的绝对路径（多级回退策略）
## 【参数】
##   p_res_path: String - 图标文件的资源路径（如 "res://core/services/app_icon.ico"）
## 【返回值】 String - 图标文件的绝对系统路径，找不到时返回空字符串
## 【回退策略】（按优先级）
##   1. user:// 目录 — 用户数据目录下的缓存文件
##      → 优先检查，避免重复提取
##   2. 编辑器模式下的全局路径 — ProjectSettings.globalize_path()
##      → 仅在编辑器模式下有效，直接访问项目文件
##   3. EXE同目录 — OS.get_executable_path().get_base_dir()
##      → 导出后的打包环境，图标与EXE在同一目录
##   4. 从res://提取 — 读取项目资源并写入user://
##      → 最终兜底方案：从游戏包中提取图标并缓存到用户目录
## 【为什么需要这种复杂的回退策略？】
##   Windows托盘图标需要.ico格式文件的绝对路径。
##   在不同运行环境（编辑器、调试运行、导出EXE）下，文件系统路径不同。
##   多级回退确保在所有环境下都能找到图标文件。
## 【边界情况】
##   - 所有路径都不存在 → 返回空字符串，调用方使用默认图标
##   - user:// 路径写入失败 → 返回空字符串
func _get_icon_path(p_res_path: String) -> String:
	var result := FileUtils.resolve_file_path(p_res_path)
	if not result.is_empty():
		return result

	return FileUtils.extract_resource_to_user(p_res_path)


## 托盘左键点击回调
## 【触发时机】用户用鼠标左键点击托盘图标时
## 【行为】发出 settings_requested 信号，使主程序打开设置窗口
func _on_tray_left_click():
	print("🖱️ [托盘] 左键点击 → 设置")
	settings_requested.emit()


## 托盘右键菜单回调（当前为退出选项）
## 【触发时机】用户在托盘右键菜单中选择时
## 【行为】发出 exit_requested 信号，使主程序执行退出逻辑
## 【注意】当前实现直接退出，若将来需要复杂的右键菜单（多选项），
##   这里需要改为菜单构建逻辑。
func _on_tray_menu_exit():
	print("🖱️ [托盘] 菜单: 退出")
	exit_requested.emit()


## 节点退出树时的清理逻辑
## 【触发时机】托盘管理器节点被从场景树中移除时
## 【核心逻辑】
##   调用 SystemTray.remove() 清理原生托盘图标，
##   防止进程退出后托盘图标仍然残留（僵尸图标）。
## 【注意】使用 has_method() 安全检查，因为 system_tray
##   可能为 null（初始化失败的情况）
func _exit_tree():
	if system_tray and system_tray.has_method("remove"):
		system_tray.remove()
