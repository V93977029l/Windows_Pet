# ============================================================================
# 文件：mouse_passthrough.gd
# ============================================================================
# 作用：
#     本文件是"鼠标穿透"GDExtension 插件的 Godot 端管理脚本。它封装了与
#     底层 C++/Rust 扩展的通信，负责插件的生命周期管理（初始化、状态更新、
#     容错处理）。
#
# 设计模式：
#     - 【单例管理器 (Singleton-like Manager)】：虽然不是 Autoload 单例，
#       但 `TP_MousePassthroughManager` 作为一个独立的管理器类，由上层节点
#       持有唯一的实例，集中管理鼠标穿透的所有交互。
#     - 【代理模式 (Proxy Pattern)】：本类作为 C++ 扩展 `MousePassthrough`
#       的 GDScript 代理层，将上层调用翻译为对底层对象的方法调用，屏蔽了
#       GDScript 与 C++ 之间的直接耦合。
#     - 【延迟初始化 + 容错】：通过 `initialization_attempted` 标记位，
#       确保初始化只尝试一次；失败时提供后备加载路径（手动 load），增强
#       了插件的鲁棒性。
#
# 架构说明：
#     整个鼠标穿透功能依赖于一个名为 `MousePassthrough` 的 C++ 类（通过
#     GDExtension 注册到 ClassDB）。核心原理是：
#       1. 将操作系统窗口的可点击区域与屏幕上渲染的内容解耦。
#       2. 当某个像素是"透明"的（即不应该被鼠标点击到时），让鼠标事件
#          穿透到窗口下方的内容。
#       3. 当某个像素是"不透明"的（即宠物或玻璃表面区域），则正常响应鼠标。
#     这种技术通常用于实现"桌面宠物"类应用的关键交互体验。
# ============================================================================

# ============================================================================
# 类：TP_MousePassthroughManager
# ============================================================================
# 职责：
#     - 管理与底层 C++ `MousePassthrough` 对象的生命周期。
#     - 提供初始化、状态更新的统一接口。
#     - 处理插件缺失时的容错逻辑。
#
# 使用方式：
#     由上层节点（如主场景脚本）创建实例，调用 `init()` 传入父节点后，
#     在每帧渲染时调用 `update_mouse_passthrough()` 同步状态。
# ============================================================================
class_name TP_MousePassthroughManager

# ---------------------------------------------------------------------------
# 成员变量
# ---------------------------------------------------------------------------

# mouse_passthrough (Object | null)
#     指向通过 ClassDB 实例化的 C++ `MousePassthrough` 对象的引用。
#     注意：该对象并非 Node 类型，因此不能添加为子节点。
#     如果插件未正确加载则为 null。
var mouse_passthrough = null

# parent_node (Node2D | null)
#     持有本管理器的父节点引用，用于访问场景树等上下文信息。
var parent_node: Node2D = null

# initialization_attempted (bool)
#     【标记位】是否已经尝试过初始化。防止初始化失败后反复重试，
#     避免每帧打印错误日志造成控制台刷屏。
#     初始值为 false；在 `init_mouse_passthrough()` 执行完毕后设为 true。
var initialization_attempted = false

# ============================================================================
# 方法：init(p_node: Node2D)
# ============================================================================
# 参数：
#     p_node (Node2D) - 持有本管理器的父节点。
#
# 返回值：无
#
# 核心逻辑：
#     保存父节点引用，然后委派给 `init_mouse_passthrough()` 执行实际的
#     插件初始化流程。
# ============================================================================
func init(p_node: Node2D):
	parent_node = p_node
	init_mouse_passthrough()

# ============================================================================
# 方法：init_mouse_passthrough()
# ============================================================================
# 参数：无
# 返回值：无
#
# 核心逻辑（初始化流程）：
#     1. 检查 `MousePassthrough` 类是否已在 ClassDB 中注册（即插件是否
#        被正确加载）。
#     2. 若注册成功，通过 `ClassDB.instantiate()` 动态实例化底层对象。
#        由于该对象不是 Node 类型，不调用 add_child()。
#     3. 配置实例：
#        - 设置窗口句柄（`set_window_handle`）：告知底层扩展要操作哪个
#          操作系统窗口。当前使用默认值 0 代表主窗口。
#        - 设置窗口标题（`set_window_title`）：用于精确定位窗口。
#        - 启用鼠标穿透（`set_mouse_passthrough`）。
#        - 隐藏任务栏图标（`hide_taskbar_icon`）：桌面宠物通常不需要
#          任务栏图标。
#        - 初始更新鼠标穿透区域（`update_mouse_passthrough(false)`）：
#          参数 false 表示当前没有不透明像素，全部区域均为透明穿透。
#     4. 若 ClassDB 中找不到该类（插件未加载），则尝试手动通过
#        `load()` 加载 `.gdextension` 文件作为后备方案。
#     5. 无论成功或失败，最后都将 `initialization_attempted` 设为 true，
#        防止后续重复初始化。
#
# 容错设计：
#     - ClassDB 检查 → 手动 load 后备 → 标记已尝试，三层保护确保不会
#       在缺少插件时崩溃或反复打印日志。
# ============================================================================
func init_mouse_passthrough():
	# 【步骤1】通过 ClassDB 动态查找 MousePassthrough 类
	# ClassDB 是 Godot 引擎的类注册中心，所有 GDExtension 注册的类都在此。
	print("📋 [插件:鼠标穿透] 开始初始化鼠标穿透插件")
	if ClassDB.class_exists("MousePassthrough"):
		print("📋 [插件:鼠标穿透] MousePassthrough类存在")
		# 【步骤2】动态实例化 C++ 对象
		# ClassDB.instantiate() 等价于在 C++ 端调用 new，但不走 Node 树。
		mouse_passthrough = ClassDB.instantiate("MousePassthrough")
		if mouse_passthrough:
			# 【步骤3】获取操作系统窗口句柄
			# 窗口句柄是操作系统分配给窗口的唯一标识符（Windows 上为 HWND）。
			# 默认使用 0 让底层扩展自行查找主窗口。
			var window_handle = 0
			print("📋 [插件:鼠标穿透] 暂时使用默认窗口句柄: ", window_handle)
			mouse_passthrough.set_window_handle(window_handle)

			# 【步骤4】设置窗口标题，底层扩展通过标题匹配精确定位窗口
			var window_title = "TransparentPet"
			print("📋 [插件:鼠标穿透] 设置窗口标题: ", window_title)
			mouse_passthrough.set_window_title(window_title)

			# 【步骤5】启用鼠标穿透功能
			# set_mouse_passthrough(true) 告诉底层：本窗口需要实现鼠标穿透行为
			mouse_passthrough.set_mouse_passthrough(true)

			# 【步骤6】隐藏任务栏图标
			# 桌面宠物应用不应在任务栏上显示独立图标
			mouse_passthrough.hide_taskbar_icon()

			# 【步骤7】初始更新鼠标穿透区域
			# 参数 false 表示：当前没有"不透明像素"需要响应鼠标，
			# 整个窗口区域都设定为穿透模式。
			mouse_passthrough.update_mouse_passthrough(false)
			print("✅ [插件:鼠标穿透] 鼠标穿透插件初始化成功")
		else:
			print("❌ [插件:鼠标穿透] 鼠标穿透插件实例化失败")
	else:
		print("❌ [插件:鼠标穿透] MousePassthrough类不存在")

		# 【容错回退】手动加载 .gdextension 文件
		# 有时 ClassDB 未注册但扩展文件存在，手动 load 可以触发注册。
		print("[插件:鼠标穿透] 尝试手动加载插件")
		var plugin_path = "res://addons/mouse_passthrough/mouse_passthrough.gdextension"
		print("[插件:鼠标穿透] 插件路径: ", plugin_path)
		var plugin = load(plugin_path)
		if plugin:
			print("✅ [插件:鼠标穿透] 插件加载成功")
		else:
			print("❌ [插件:鼠标穿透] 插件加载失败")

	# 【步骤8】标记初始化已尝试，防止后续重复执行
	initialization_attempted = true

# ============================================================================
# 方法：update_mouse_passthrough(has_opaque_pixel: bool)
# ============================================================================
# 参数：
#     has_opaque_pixel (bool) - 当前帧是否有不透明像素需要鼠标响应。
#         true  → 存在不透明区域，鼠标在该区域不应穿透。
#         false → 全部透明，鼠标在整个窗口都应穿透到下层。
#
# 返回值：无
#
# 核心逻辑：
#     每帧根据渲染结果更新鼠标穿透区域。如果底层对象已初始化，直接调用
#     其 `update_mouse_passthrough()` 方法；如果尚未初始化，且未尝试过
#     初始化，则触发懒加载初始化流程。
#
# 使用场景：
#     此方法应在主循环的 `_process()` 中每帧调用。渲染器根据当前画面的
#     透明/不透明分布，决定鼠标的行为模式。
# ============================================================================
func update_mouse_passthrough(has_opaque_pixel: bool):
	if mouse_passthrough:
		# 正常路径：底层对象已就绪，直接同步状态
		mouse_passthrough.update_mouse_passthrough(has_opaque_pixel)
	else:
		# 容错路径：底层对象不存在，且尚未尝试初始化
		# 仅在 initialization_attempted 为 false 时才触发初始化，
		# 避免每帧都重复打印错误日志（防止控制台刷屏）。
		if not initialization_attempted:
			print("📋 [插件:鼠标穿透] 鼠标穿透插件未初始化")
			init_mouse_passthrough()
