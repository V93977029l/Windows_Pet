class_name DragController
extends RefCounted

var parent_node: Node2D
var click_offset: Vector2i = Vector2i.ZERO
var is_dragging: bool = false
var drag_target: Sprite2D = null

func init(node: Node2D):
	parent_node = node
	print("✅ [拖动] 拖动逻辑初始化完成")

func handle_area_input_event(event: InputEvent, target_sprite: Sprite2D = null):
	if not parent_node:
		return

	if not target_sprite:
		target_sprite = parent_node.get_node("Blue")

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_global: Vector2 = parent_node.get_global_mouse_position()
			var target_global: Vector2 = target_sprite.global_position
			click_offset = Vector2i(int(round(mouse_global.x - target_global.x)), int(round(mouse_global.y - target_global.y)))
			is_dragging = true
			drag_target = target_sprite
			print("[拖动] 左键按下，开始拖动，目标:", target_sprite.name, "偏移:", click_offset)
		else:
			is_dragging = false
			drag_target = null
			print("[拖动] 左键松开，停止拖动")

func update_drag():
	if not parent_node or not is_dragging or not drag_target:
		return

	var mouse_global: Vector2 = parent_node.get_global_mouse_position()
	var new_pos: Vector2 = Vector2(mouse_global.x - click_offset.x, mouse_global.y - click_offset.y)
	drag_target.global_position = new_pos
