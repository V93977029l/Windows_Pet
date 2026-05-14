var parent_node: Node2D
var click_offset: Vector2i = Vector2i.ZERO
var is_dragging: bool = false

func init(node: Node2D):
	parent_node = node
	print("✅ [拖动] 拖动逻辑初始化完成")

func handle_area_input_event(event: InputEvent):
	if not parent_node:
		print("❌ [拖动] 父节点为空")
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_global: Vector2 = parent_node.get_global_mouse_position()
			var pet_global: Vector2 = parent_node.get_node("Sprite2D").global_position
			click_offset = Vector2i(int(round(mouse_global.x - pet_global.x)), int(round(mouse_global.y - pet_global.y)))
			is_dragging = true
			print("[拖动] 左键按下，开始拖动，偏移：", click_offset)
		else:
			is_dragging = false
			print("[拖动] 左键松开，停止拖动")

func update_drag():
	if not parent_node or not is_dragging:
		return

	var mouse_global: Vector2 = parent_node.get_global_mouse_position()
	var new_pos: Vector2 = Vector2(mouse_global.x - click_offset.x, mouse_global.y - click_offset.y)
	parent_node.get_node("Sprite2D").global_position = new_pos
