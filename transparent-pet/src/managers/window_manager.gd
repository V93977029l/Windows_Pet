class_name TP_WindowManager

var owner: Node2D = null

func init(owner_node: Node2D):
	owner = owner_node
	print("✅ [窗口管理] 窗口管理器初始化完成")

func set_always_on_top(enabled: bool):
	if owner:
		owner.get_window().always_on_top = enabled

func get_window() -> Window:
	return owner.get_window() if owner else null

func get_window_size() -> Vector2i:
	return get_window().size if get_window() else Vector2i.ZERO

func get_window_position() -> Vector2i:
	return get_window().position if get_window() else Vector2i.ZERO
	