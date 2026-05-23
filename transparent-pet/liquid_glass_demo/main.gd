extends Node2D

@onready var renderer: Node2D = $LiquidGlassRenderer
@onready var control_panel: PanelContainer = $ControlPanel

var is_dragging = false

func _ready():
	set_process_input(true)
	control_panel.visible = false
	
	if renderer:
		var dpr: float = get_tree().root.content_scale_factor
		var viewport_size = Vector2(get_viewport_rect().size.x * dpr, get_viewport_rect().size.y * dpr)
		renderer.set_mouse_position(viewport_size / 2)
		renderer.set_mouse_spring(viewport_size / 2)

func _input(event: InputEvent):
	var dpr: float = get_tree().root.content_scale_factor
	
	if event is InputEventMouseMotion:
		if is_dragging and renderer:
			var item_manager = renderer.get_item_manager()
			item_manager.update_drag(event.position * dpr)
			
			renderer.set_mouse_position(event.position * dpr)
			renderer.set_mouse_spring(event.position * dpr)
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if renderer:
				var item_manager = renderer.get_item_manager()
				is_dragging = item_manager.start_drag(event.position * dpr)
				
				renderer.set_mouse_position(event.position * dpr)
				renderer.set_mouse_spring(event.position * dpr)
		else:
			is_dragging = false
			if renderer:
				var item_manager = renderer.get_item_manager()
				item_manager.end_drag()
	
	elif event is InputEventKey:
		if event.keycode == KEY_SPACE and event.pressed:
			control_panel.visible = !control_panel.visible