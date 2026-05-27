extends Node
class_name PetEffectsAPI

@warning_ignore("unused_signal")
signal effect_activated(effect_id: String)
@warning_ignore("unused_signal")
signal effect_deactivated(effect_id: String)

func init(_parent_node: Node2D, _target_sprite: Sprite2D, _config):
	push_error("[PetEffects] init() must be overridden")

func activate_effect(_effect_id: String):
	push_error("[PetEffects] activate_effect() must be overridden")

func deactivate_effect(_effect_id: String):
	push_error("[PetEffects] deactivate_effect() must be overridden")

func sync_position(_global_pos: Vector2, _dpr: float):
	push_error("[PetEffects] sync_position() must be overridden")

func has_active_effect() -> bool:
	push_error("[PetEffects] has_active_effect() must be overridden")
	return false

func get_active_effect_id() -> String:
	push_error("[PetEffects] get_active_effect_id() must be overridden")
	return ""
