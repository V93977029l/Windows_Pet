# 鼠标穿透插件
# 功能：提供鼠标穿透功能的核心逻辑

class_name TP_MousePassthroughManager

var mouse_passthrough = null
var parent_node: Node2D = null
var initialization_attempted = false  # 跟踪是否已经尝试初始化

# 初始化函数
func init(p_node: Node2D):
	parent_node = p_node
	init_mouse_passthrough()

# 初始化鼠标穿透插件
func init_mouse_passthrough():
	# 尝试通过ClassDB实例化MousePassthrough类
	print("📋 [插件:鼠标穿透] 开始初始化鼠标穿透插件")
	if ClassDB.class_exists("MousePassthrough"):
		print("📋 [插件:鼠标穿透] MousePassthrough类存在")
		mouse_passthrough = ClassDB.instantiate("MousePassthrough")
		if mouse_passthrough:
			# 不需要添加为子节点，因为MousePassthrough不是Node类型
			# 获取窗口句柄并传递给C++扩展
			# 在Godot 4中，我们使用DisplayServer获取窗口句柄
			var window_handle = 0
			# 尝试获取窗口ID和窗口句柄
			print("📋 [插件:鼠标穿透] 暂时使用默认窗口句柄: ", window_handle)
			mouse_passthrough.set_window_handle(window_handle)
			
			# 设置窗口标题
			var window_title = "TransparentPet"
			print("📋 [插件:鼠标穿透] 设置窗口标题: ", window_title)
			mouse_passthrough.set_window_title(window_title)
			
			mouse_passthrough.set_mouse_passthrough(true)
			# 初始化后立即更新一次穿透状态，确保默认是可穿透的
			mouse_passthrough.update_mouse_passthrough(false)
			print("✅ [插件:鼠标穿透] 鼠标穿透插件初始化成功")
		else:
			print("❌ [插件:鼠标穿透] 鼠标穿透插件实例化失败")
	else:
		print("❌ [插件:鼠标穿透] MousePassthrough类不存在")
		
		# 尝试手动加载插件
		print("[插件:鼠标穿透] 尝试手动加载插件")
		var plugin_path = "res://addons/mouse_passthrough/mouse_passthrough.gdextension"
		print("[插件:鼠标穿透] 插件路径: ", plugin_path)
		var plugin = load(plugin_path)
		if plugin:
			print("✅ [插件:鼠标穿透] 插件加载成功")
		else:
			print("❌ [插件:鼠标穿透] 插件加载失败")
		
	initialization_attempted = true

# 更新鼠标穿透状态
func update_mouse_passthrough(has_opaque_pixel: bool):
	if mouse_passthrough:
		mouse_passthrough.update_mouse_passthrough(has_opaque_pixel)
	else:
		# 只在初始化失败时打印一次，避免每帧打印
		if not initialization_attempted:
			print("📋 [插件:鼠标穿透] 鼠标穿透插件未初始化")
			init_mouse_passthrough()
