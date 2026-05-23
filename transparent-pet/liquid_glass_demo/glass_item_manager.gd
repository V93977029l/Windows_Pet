class_name GlassItemManager

const MAX_ITEMS: int = 3

var items: Array[GlassItem] = []
var selected_item_index: int = -1
var drag_offset: Vector2 = Vector2.ZERO

signal item_selected(index: int)
signal item_moved(index: int, position: Vector2)

func _init():
	items = []

func add_item(item: GlassItem) -> int:
	if items.size() >= MAX_ITEMS:
		return -1
	items.append(item)
	return items.size() - 1

func remove_item(index: int) -> bool:
	if index < 0 or index >= items.size():
		return false
	items.remove_at(index)
	if selected_item_index == index:
		selected_item_index = -1
	elif selected_item_index > index:
		selected_item_index -= 1
	return true

func get_item(index: int) -> GlassItem:
	if index < 0 or index >= items.size():
		return null
	return items[index]

func get_items() -> Array[GlassItem]:
	return items

func select_item_at_position(position: Vector2) -> int:
	for i in range(items.size() - 1, -1, -1):
		var item = items[i]
		if item.enabled and item.contains_point(position):
			selected_item_index = i
			item_selected.emit(selected_item_index)
			return i
	selected_item_index = -1
	return -1

func start_drag(position: Vector2) -> bool:
	var index = select_item_at_position(position)
	if index >= 0:
		var item = items[index]
		drag_offset = item.position - position
		return true
	return false

func update_drag(position: Vector2):
	if selected_item_index >= 0 and selected_item_index < items.size():
		var item = items[selected_item_index]
		item.position = position + drag_offset
		item_moved.emit(selected_item_index, item.position)

func end_drag():
	selected_item_index = -1
	drag_offset = Vector2.ZERO

func get_selected_item() -> GlassItem:
	if selected_item_index >= 0 and selected_item_index < items.size():
		return items[selected_item_index]
	return null

func clear_all():
	items.clear()
	selected_item_index = -1

func get_items_for_shader() -> Array:
	var result: Array = []
	for i in range(MAX_ITEMS):
		if i < items.size():
			result.append(items[i].to_shader_params())
		else:
			result.append({
				"position": Vector2.ZERO,
				"width": 0.0,
				"height": 0.0,
				"radius": 0.0,
				"roundness": 0.0,
				"shape_type": 0.0,
				"enabled": 0.0,
				"scale": 0.0
			})
	return result

func init_default_items(viewport_size: Vector2):
	clear_all()
	
	var circle_item = GlassItem.new()
	circle_item.shape_type = GlassItem.ShapeType.CIRCLE
	circle_item.position = Vector2(viewport_size.x * 0.3, viewport_size.y * 0.3)
	circle_item.width = 150.0
	circle_item.height = 150.0
	circle_item.radius = 75.0
	circle_item.scale = 1.0
	circle_item.enabled = true
	add_item(circle_item)
	
	var rect_item = GlassItem.new()
	rect_item.shape_type = GlassItem.ShapeType.ROUNDED_RECT
	rect_item.position = Vector2(viewport_size.x * 0.7, viewport_size.y * 0.3)
	rect_item.width = 150.0
	rect_item.height = 150.0
	rect_item.radius = 30.0
	rect_item.roundness = 5.0
	rect_item.scale = 1.0
	rect_item.enabled = true
	add_item(rect_item)
	
	var slime_item = GlassItem.new()
	slime_item.shape_type = GlassItem.ShapeType.SLIME
	slime_item.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.65)
	slime_item.width = 180.0
	slime_item.height = 120.0
	slime_item.radius = 60.0
	slime_item.scale = 1.0
	slime_item.enabled = true
	add_item(slime_item)
