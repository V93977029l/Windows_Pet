# 删掉extends Node，默认继承RefCounted，无需空节点
var parent_node: Node2D # 主节点引用
var click_offset: Vector2i = Vector2i.ZERO
var is_dragging: bool = false

# 初始化（接收主节点）
func init(node: Node2D):
	parent_node = node
	print("✅ 拖动逻辑初始化完成")

# 处理Area2D的点击事件（触发拖动）
func handle_area_input_event(event: InputEvent):
	if not parent_node: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_global: Vector2i = DisplayServer.mouse_get_position()
			click_offset = mouse_global - parent_node.get_window().position
			is_dragging = true
		else:
			is_dragging = false

# 处理Input事件（执行拖动）
func handle_drag_input(event: InputEvent):
	if not parent_node: return
	
	# 左键松开停止拖动
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragging = false
	# 执行拖动
	if is_dragging and event is InputEventMouseMotion:
		var mouse_global: Vector2i = DisplayServer.mouse_get_position()
		parent_node.get_window().position = mouse_global - click_offset
