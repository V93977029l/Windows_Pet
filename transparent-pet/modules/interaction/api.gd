class_name PetInteractionAPI
extends Node

@warning_ignore("unused_signal")
signal drag_started(target_sprite: Sprite2D)
@warning_ignore("unused_signal")
signal drag_ended()
@warning_ignore("unused_signal")
signal throw_started(velocity: Vector2)
@warning_ignore("unused_signal")
signal throw_stopped()
@warning_ignore("unused_signal")
signal mouse_entered_sprite()
@warning_ignore("unused_signal")
signal mouse_exited_sprite()

var drag_controller = null
var mouse_manager = null

func init(_parent_node: Node2D, _sprite: Sprite2D, _passthrough_manager):
	push_error("[PetInteraction] init() must be overridden")

func update_drag(_delta: float):
	push_error("[PetInteraction] update_drag() must be overridden")

func update_mouse_passthrough():
	push_error("[PetInteraction] update_mouse_passthrough() must be overridden")

func handle_area_input_event(_event: InputEvent, _target_sprite: Sprite2D = null):
	push_error("[PetInteraction] handle_area_input_event() must be overridden")

func update_throw_params(_gravity: float, _min_speed: float, _max_speed: float, _multiplier: float, _enabled: bool):
	push_error("[PetInteraction] update_throw_params() must be overridden")

func update_physics_params(_ground_b: float, _wall_b: float, _friction: float, _fall: float):
	push_error("[PetInteraction] update_physics_params() must be overridden")

func update_svg_params(_half_w_ratio: float, _bottom_offset_ratio: float, _fallback_x: int, _fallback_y: int):
	push_error("[PetInteraction] update_svg_params() must be overridden")

func is_mouse_over_any() -> bool:
	push_error("[PetInteraction] is_mouse_over_any() must be overridden")
	return false

func is_dragging() -> bool:
	push_error("[PetInteraction] is_dragging() must be overridden")
	return false

func is_throwing() -> bool:
	push_error("[PetInteraction] is_throwing() must be overridden")
	return false
