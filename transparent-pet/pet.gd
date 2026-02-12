extends Node2D

@onready var pet_sprite: Sprite2D = $Sprite2D  
# 记录点击偏移（整型，无精度误差）
var click_offset: Vector2i = Vector2i.ZERO
# 拖动标记（全局生效）
var is_dragging: bool = false

func _ready():
	# 窗口尺寸适配
	if pet_sprite and pet_sprite.texture:
		var sprite_size: Vector2 = pet_sprite.texture.get_size()
		var sprite_size_i: Vector2i = Vector2i(int(round(sprite_size.x)), int(round(sprite_size.y)))
		get_window().size = sprite_size_i
		
		# 窗口居中
		var screen_size_i: Vector2i = DisplayServer.screen_get_size()
		var window_pos_i: Vector2i = (screen_size_i - sprite_size_i) / 2
		get_window().position = window_pos_i

# 仅用于检测“鼠标在碰撞区内按下”（触发拖动开始）
func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# 只有在碰撞区内按下左键，才开始拖动
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 记录鼠标与窗口的偏移（用全局鼠标位置，无视口干扰）
			var mouse_global: Vector2i = DisplayServer.mouse_get_position()
			click_offset = mouse_global - get_window().position
			is_dragging = true
		else:
			is_dragging = false

# 全局输入事件：只要拖动状态为true，无论鼠标在哪都持续更新位置
func _input(event: InputEvent) -> void:
	# 1. 全局监听鼠标松开（防止鼠标移出碰撞区后松不开）
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragging = false
	
	# 2. 拖动状态下，实时更新窗口位置（不受碰撞区限制）
	if is_dragging and event is InputEventMouseMotion:
		var mouse_global: Vector2i = DisplayServer.mouse_get_position()
		var target_pos: Vector2i = mouse_global - click_offset
		# 直接设置窗口位置，全程整型无抖动
		get_window().position = target_pos
