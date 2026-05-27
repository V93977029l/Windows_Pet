class_name DragController
extends RefCounted

var parent_node: Node2D

var click_offset: Vector2i = Vector2i.ZERO
var is_dragging: bool = false
var drag_target: Sprite2D = null

var is_throwing: bool = false
var throw_velocity: Vector2 = Vector2.ZERO

var throw_gravity: float = 800.0
var throw_min_speed: float = 350.0
var throw_max_speed: float = 800.0
var throw_multiplier: float = 2.0
var throw_enabled: bool = true

var ground_bounce: float = 0.3
var wall_bounce: float = 0.7
var ground_friction: float = 500.0
var fall_threshold: float = 500.0

var svg_half_w_ratio: float = 0.4
var svg_bottom_offset_ratio: float = 0.417
var svg_fallback: Vector2 = Vector2(200, 132)

const VELOCITY_BUFFER_SIZE: int = 8
var velocity_buffer: Array[Vector2] = []
var pos_buffer: Array[Vector2] = []

var last_mouse_pos: Vector2 = Vector2.ZERO
var last_frame_time: float = 0.0
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_start_time: float = 0.0


func init(node: Node2D):
	parent_node = node
	print("✅ [拖动] 拖动逻辑初始化完成")


func update_throw_params(gravity: float, min_speed: float, max_speed: float, multiplier: float, enabled: bool):
	throw_gravity = gravity
	throw_min_speed = min_speed
	throw_max_speed = max_speed
	throw_multiplier = multiplier
	throw_enabled = enabled
	print("✅ [抛射] 参数已更新: 重力=", gravity, " 最小=", min_speed, " 最大=", max_speed, " 倍率=", multiplier, " 启用=", enabled)


func update_physics_params(ground_b: float, wall_b: float, friction: float, fall: float):
	ground_bounce = ground_b
	wall_bounce = wall_b
	ground_friction = friction
	fall_threshold = fall
	print("✅ [物理] 参数已更新: 地面弹性=", ground_b, " 墙壁弹性=", wall_b, " 摩擦力=", friction, " 安全阈值=", fall)


func update_svg_params(half_w_ratio: float, bottom_offset_ratio: float, fallback_x: int, fallback_y: int):
	svg_half_w_ratio = half_w_ratio
	svg_bottom_offset_ratio = bottom_offset_ratio
	svg_fallback = Vector2(fallback_x, fallback_y)


func handle_area_input_event(event: InputEvent, target_sprite: Sprite2D = null):
	if not parent_node:
		return

	if not target_sprite:
		target_sprite = parent_node.get_node("Slime")

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_global: Vector2 = parent_node.get_global_mouse_position()
			var target_global: Vector2 = target_sprite.global_position
			click_offset = Vector2i(int(round(mouse_global.x - target_global.x)), int(round(mouse_global.y - target_global.y)))
			is_dragging = true
			drag_target = target_sprite
			is_throwing = false
			throw_velocity = Vector2.ZERO
			drag_start_pos = mouse_global
			drag_start_time = Time.get_ticks_msec()
			last_mouse_pos = mouse_global
			last_frame_time = Time.get_ticks_msec()
			velocity_buffer.clear()
			pos_buffer.clear()
			print("[拖动] 左键按下，开始拖动，目标:", target_sprite.name, "偏移:", click_offset)
		else:
			is_dragging = false

			if not throw_enabled:
				print("[拖动] 左键松开，停止拖动（抛射已禁用）")
				return

			var avg_velocity = Vector2.ZERO
			if velocity_buffer.size() > 0:
				for v in velocity_buffer:
					avg_velocity += v
				avg_velocity /= velocity_buffer.size()

			throw_velocity = avg_velocity * throw_multiplier

			var speed = throw_velocity.length()

			if speed > throw_max_speed:
				throw_velocity = throw_velocity.normalized() * throw_max_speed
				speed = throw_max_speed

			if speed > throw_min_speed:
				is_throwing = true
				print("[抛射] 开始抛物线运动，速度:", throw_velocity, "速度大小:", speed)
			else:
				is_throwing = false
				throw_velocity = Vector2.ZERO
				print("[拖动] 左键松开，停止拖动（速度不足:", round(speed), "/ ", throw_min_speed, "）")


func update_drag(delta: float = 0.0167):
	if not parent_node or not drag_target:
		return

	if is_dragging:
		var mouse_global: Vector2 = parent_node.get_global_mouse_position()
		var new_pos: Vector2 = Vector2(mouse_global.x - click_offset.x, mouse_global.y - click_offset.y)
		drag_target.global_position = new_pos

		var current_time = Time.get_ticks_msec()
		var time_delta = current_time - last_frame_time
		if time_delta > 0:
			var frame_velocity = (mouse_global - last_mouse_pos) / (time_delta / 1000.0)

			velocity_buffer.append(frame_velocity)
			while velocity_buffer.size() > VELOCITY_BUFFER_SIZE:
				velocity_buffer.pop_front()

		last_mouse_pos = mouse_global
		last_frame_time = current_time
	elif is_throwing:
		throw_velocity.y += throw_gravity * delta

		var new_pos = drag_target.global_position + throw_velocity * delta
		var screen_size = parent_node.get_tree().root.get_viewport().get_size()

		# 矩形碰撞半尺寸（按 SVG 实际轮廓相对于画布中心的偏移）
		var tex_size = drag_target.texture.get_size() if drag_target.texture else svg_fallback
		var half_w = tex_size.x * svg_half_w_ratio * drag_target.scale.x
		var bottom_h = tex_size.y * svg_bottom_offset_ratio * drag_target.scale.y

		# 底部：落在地面上时反弹，并标记为接地状态
		var on_ground = false
		if new_pos.y + bottom_h > screen_size.y:
			new_pos.y = screen_size.y - bottom_h
			throw_velocity.y = -abs(throw_velocity.y) * ground_bounce
			on_ground = true

		# 左墙反弹
		if new_pos.x - half_w < 0:
			new_pos.x = half_w
			throw_velocity.x = abs(throw_velocity.x) * wall_bounce

		# 右墙反弹
		if new_pos.x + half_w > screen_size.x:
			new_pos.x = screen_size.x - half_w
			throw_velocity.x = -abs(throw_velocity.x) * wall_bounce

		# 地面摩擦力：接地的每一帧都持续减速水平速度
		if on_ground:
			var friction_amount = ground_friction * delta
			if abs(throw_velocity.x) <= friction_amount:
				throw_velocity.x = 0.0
			else:
				throw_velocity.x -= sign(throw_velocity.x) * friction_amount

		drag_target.global_position = new_pos

		# 安全网：若掉出屏幕下方太远（如窗口被隐藏），强制停止
		if new_pos.y > screen_size.y + fall_threshold:
			is_throwing = false
			throw_velocity = Vector2.ZERO
			print("[抛射] 安全网触发，结束抛物线运动")
