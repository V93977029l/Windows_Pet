extends Node2D

@onready var renderer: Node2D = $LiquidGlassRenderer
@onready var control_panel: PanelContainer = $ControlPanel

var is_dragging = false
var block_pos = Vector2.ZERO
var drag_offset = Vector2.ZERO
var block_size = Vector2(200.0, 200.0)  # 小方块尺寸

func _ready():
	set_process_input(true)
	control_panel.visible = false
	# 初始化方块位置在屏幕中心
	block_pos = get_viewport_rect().size / 2
	
	if renderer:
		renderer.set_mouse_position(block_pos)
		renderer.set_mouse_spring(block_pos)

func is_point_in_block(point: Vector2) -> bool:
	# 判断点是否在小方块区域内
	var half_size = block_size / 2.0
	var rect = Rect2(block_pos - half_size, block_size)
	return rect.has_point(point)

func _input(event: InputEvent):
	if event is InputEventMouseMotion:
		if is_dragging:
			block_pos = event.position + drag_offset
		
		if renderer:
			renderer.set_mouse_position(block_pos)
			renderer.set_mouse_spring(block_pos)
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 只有点击在小方块区域内才开始拖动
			if is_point_in_block(event.position):
				is_dragging = true
				drag_offset = block_pos - event.position
		else:
			is_dragging = false
	
	elif event is InputEventKey:
		if event.keycode == KEY_SPACE and event.pressed:
			control_panel.visible = !control_panel.visible
