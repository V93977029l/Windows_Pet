extends Node2D

@onready var renderer: Node2D = $LiquidGlassRenderer
@onready var control_panel: PanelContainer = $ControlPanel

var is_dragging = false
var dragged_item_index = -1
var drag_offset = Vector2.ZERO

func _ready():
	set_process_input(true)
	control_panel.visible = false
	
	if renderer:
		renderer.set_mouse_position(Vector2.ZERO)
		renderer.set_mouse_spring(Vector2.ZERO)

func _input(event: InputEvent):
	if event is InputEventMouseMotion:
		if is_dragging and dragged_item_index >= 0:
			var item_manager = renderer.get_item_manager()
			var items = item_manager.get_items()
			if dragged_item_index < items.size():
				var item = items[dragged_item_index]
				item.position = event.position + drag_offset
		
		if renderer:
			renderer.set_mouse_position(event.position)
			renderer.set_mouse_spring(event.position)
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if renderer:
				var item_manager = renderer.get_item_manager()
				dragged_item_index = item_manager.select_item_at_position(event.position)
				if dragged_item_index >= 0:
					is_dragging = true
					var items = item_manager.get_items()
					var item = items[dragged_item_index]
					drag_offset = item.position - event.position
		else:
			is_dragging = false
			dragged_item_index = -1
	
	elif event is InputEventKey:
		if event.keycode == KEY_SPACE and event.pressed:
			control_panel.visible = !control_panel.visible
