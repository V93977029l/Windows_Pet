class_name TP_MaterialManager

var liquid_shader: Shader = preload("res://assets/shaders/liquid_glass.gdshader")

var target_sprite: Sprite2D = null

func init(sprite: Sprite2D):
	target_sprite = sprite

func apply_preset(preset: Dictionary):
	if not preset:
		print("[材质] 错误：未指定预设")
		return
	
	if not target_sprite:
		print("[材质] 错误：未设置目标精灵")
		return
	
	var glass_color = preset.get("glass_color", Color(0.1, 0.3, 0.6, 1.0))
	var edge_glow = preset.get("edge_glow", 0.8)
	var highlight_intensity = preset.get("highlight_intensity", 1.0)
	var liquid_wobble = preset.get("liquid_wobble", 0.3)
	var wobble_speed = preset.get("wobble_speed", 2.0)
	var fresnel_power = preset.get("fresnel_power", 3.0)
	var enable_dynamic = preset.get("enable_dynamic", true)
	var preset_name = preset.get("name", "液态玻璃")
	
	var material = ShaderMaterial.new()
	material.shader = liquid_shader
	material.set_shader_parameter("glass_color", Vector4(glass_color.r, glass_color.g, glass_color.b, glass_color.a))
	material.set_shader_parameter("edge_glow", edge_glow)
	material.set_shader_parameter("highlight_intensity", highlight_intensity)
	material.set_shader_parameter("liquid_wobble", liquid_wobble)
	material.set_shader_parameter("wobble_speed", wobble_speed)
	material.set_shader_parameter("fresnel_power", fresnel_power)
	material.set_shader_parameter("enable_dynamic", enable_dynamic)
	
	target_sprite.material = material
	print("[材质] 已应用预设: ", preset_name, "，动态效果: ", enable_dynamic)

func get_current_material_name() -> String:
	return "液态玻璃"

func get_preset_names() -> Array:
	return ["液态玻璃"]

func set_dynamic_enabled(enabled: bool):
	if not target_sprite or not target_sprite.material:
		return
	
	var material = target_sprite.material
	if material is ShaderMaterial:
		material.set_shader_parameter("enable_dynamic", enabled)
		print("[材质] 动态效果已", "启用" if enabled else "禁用")
