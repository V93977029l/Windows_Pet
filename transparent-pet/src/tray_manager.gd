class_name TrayManager
extends Node

signal settings_requested
signal exit_requested

var system_tray = null
var initialization_attempted = false

func init(_pet: Node2D):
	init_system_tray()

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
	
	initialization_attempted = true

func _create_tray():
	system_tray = ClassDB.instantiate("SystemTray")
	if not system_tray:
		print("❌ [托盘] SystemTray 实例化失败")
		return
	
	system_tray.set_window_title("TransparentPet")
	system_tray.create("桌宠")
	
	var ico_path = ProjectSettings.globalize_path("res://assets/icons/app_icon.ico")
	system_tray.set_icon(ico_path)
	
	system_tray.set_left_click_callback(Callable(self, "_on_tray_left_click"))
	system_tray.set_right_click_callback(Callable(self, "_on_tray_menu_exit"))
	
	system_tray.show()
	system_tray.hide_taskbar_icon()
	
	print("✅ [托盘] 原生系统托盘已创建")

func _on_tray_left_click():
	print("🖱️ [托盘] 左键点击 → 设置")
	settings_requested.emit()

func _on_tray_menu_exit():
	print("🖱️ [托盘] 菜单: 退出")
	exit_requested.emit()

func _exit_tree():
	if system_tray and system_tray.has_method("remove"):
		system_tray.remove()
