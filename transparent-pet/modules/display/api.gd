class_name PetDisplayAPI
extends Node

@warning_ignore("unused_signal")
signal scale_changed(new_scale: float)
@warning_ignore("unused_signal")
signal material_changed(preset_id: String)

var vector_renderer = null
var material_manager: MaterialManager = null

func init(_sprite: Sprite2D, _svg_path: String):
	push_error("[PetDisplay] init() must be overridden")

func update_scale(_new_scale: float):
	push_error("[PetDisplay] update_scale() must be overridden")

func apply_high_res_scale(_new_scale: float):
	push_error("[PetDisplay] apply_high_res_scale() must be overridden")

func apply_preset(_preset) -> String:
	push_error("[PetDisplay] apply_preset() must be overridden")
	return ""

func apply_preset_by_id(_preset_id: String) -> String:
	push_error("[PetDisplay] apply_preset_by_id() must be overridden")
	return ""

func get_current_material_name() -> String:
	push_error("[PetDisplay] get_current_material_name() must be overridden")
	return ""

func set_breathing_enabled(_enabled: bool):
	push_error("[PetDisplay] set_breathing_enabled() must be overridden")

func set_motion_effect_enabled(_enabled: bool):
	push_error("[PetDisplay] set_motion_effect_enabled() must be overridden")

func get_all_presets() -> Array:
	push_error("[PetDisplay] get_all_presets() must be overridden")
	return []

func get_preset_by_id(_id: String):
	push_error("[PetDisplay] get_preset_by_id() must be overridden")
	return null
