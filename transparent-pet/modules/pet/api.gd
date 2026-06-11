class_name PetAPI
extends Node

## ============================================================================
## modules/pet/api.gd — Pet 模块的公共接口契约
## ============================================================================

signal pet_scale_changed(new_scale: float)
signal material_changed(preset_id: String)
signal settings_requested
signal exit_requested

func open_settings_window():
	push_error("[Pet API] open_settings_window() must be implemented by pet_core")

func update_pet_scale(new_scale: float):
	push_error("[Pet API] update_pet_scale() must be implemented by pet_core")

func apply_high_res_scale(new_scale: float):
	push_error("[Pet API] apply_high_res_scale() must be implemented by pet_core")

func get_current_material_name(slime_id: String = "slime_1") -> String:
	push_error("[Pet API] get_current_material_name() must be implemented by pet_core")
	return ""

func on_material_changed(preset_id: String):
	push_error("[Pet API] on_material_changed() must be implemented by pet_core")

func save_config():
	push_error("[Pet API] save_config() must be implemented by pet_core")

func get_all_presets() -> Array:
	push_error("[Pet API] get_all_presets() must be implemented by pet_core")
	return []

func apply_preset(preset) -> String:
	push_error("[Pet API] apply_preset() must be implemented by pet_core")
	return ""

func set_breathing_enabled(enabled: bool):
	push_error("[Pet API] set_breathing_enabled() must be implemented by pet_core")

func set_motion_effect_enabled(enabled: bool):
	push_error("[Pet API] set_motion_effect_enabled() must be implemented by pet_core")

func update_throw_params(gravity: float, min_speed: float, max_speed: float, multiplier: float, enabled: bool):
	push_error("[Pet API] update_throw_params() must be implemented by pet_core")
