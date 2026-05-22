class_name MaterialManager
extends RefCounted

class MaterialPreset:
	var id: String
	var name: String
	var description: String = ""
	var parameters: Dictionary = {}

	func _init(preset_id: String, preset_name: String):
		id = preset_id
		name = preset_name

	func to_dict() -> Dictionary:
		var data: Dictionary = {
			"id": id,
			"name": name,
			"description": description,
			"parameters": parameters.duplicate()
		}
		return data

	func from_dict(data: Dictionary):
		id = data.get("id", id)
		name = data.get("name", name)
		description = data.get("description", description)
		parameters = data.get("parameters", {}).duplicate()

class MaterialRegistry:
	var presets: Dictionary = {}

	func register_preset(preset):
		presets[preset.id] = preset
		print("[MaterialRegistry] Registered preset: ", preset.name)

	func get_preset(id: String):
		return presets.get(id, null)

	func get_all_preset_names() -> Array:
		return presets.keys()

	func get_all_presets() -> Array:
		return presets.values()

var registry = null
var target_sprite: Sprite2D = null
var current_preset = null
var current_material: ShaderMaterial = null

func _init():
	registry = MaterialRegistry.new()
	_register_default_presets()

func init(sprite: Sprite2D):
	target_sprite = sprite

func _register_default_presets():
	var blue_slime = MaterialPreset.new("blue_slime", "蓝色史莱姆")
	blue_slime.description = "可爱的蓝色史莱姆材质"
	registry.register_preset(blue_slime)

	var liquid_glass = MaterialPreset.new("liquid_glass", "液态玻璃")
	liquid_glass.description = "苹果风格液态玻璃效果"
	registry.register_preset(liquid_glass)

func apply_preset(preset):
	if not target_sprite:
		print("[MaterialManager] Error: Target sprite not set")
		return
	
	if preset != null and typeof(preset) == TYPE_OBJECT and "id" in preset:
		_apply_preset_object(preset)
	elif typeof(preset) == TYPE_DICTIONARY:
		apply_preset_dict(preset)
	else:
		print("[MaterialManager] Error: Invalid preset type")

func _get_shader_for_preset(_preset_id: String) -> Resource:
	match _preset_id:
		"liquid_glass":
			return preload("res://assets/shaders/liquid_glass.gdshader")
		_:
			return preload("res://assets/shaders/slime.gdshader")

func _apply_preset_object(preset):
	current_preset = preset
	
	current_material = ShaderMaterial.new()
	current_material.shader = _get_shader_for_preset(preset.id)
	
	target_sprite.material = current_material
	print("[MaterialManager] Applied preset: ", preset.name)

func apply_preset_dict(preset_data: Dictionary):
	if not target_sprite:
		print("[MaterialManager] Error: Target sprite not set")
		return
	
	current_material = ShaderMaterial.new()
	
	var preset_id = preset_data.get("id", "blue_slime")
	current_material.shader = _get_shader_for_preset(preset_id)
	
	target_sprite.material = current_material
	print("[MaterialManager] Applied preset dict: ", preset_id)

func set_dynamic_enabled(enabled: bool):
	if current_material:
		current_material.set_shader_parameter("enable_dynamic", enabled)
		print("[MaterialManager] Dynamic effect ", "enabled" if enabled else "disabled")

func get_current_material_name() -> String:
	if current_preset:
		return current_preset.name
	return "蓝色史莱姆"

func get_current_preset():
	return current_preset

func get_current_material() -> ShaderMaterial:
	return current_material

func get_preset_by_id(id: String):
	return registry.get_preset(id)

func get_all_presets() -> Array:
	return registry.get_all_presets()