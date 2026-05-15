##
# 材质管理器类
# 负责管理桌宠的材质系统，包括着色器加载、预设应用和材质切换
##
class_name PetMaterialManager

# 液态玻璃着色器资源
var liquid_shader: Shader = preload("res://assets/shaders/liquid_glass.gdshader")
# 毛玻璃着色器资源
var frosted_shader: Shader = preload("res://assets/shaders/frosted_glass.gdshader")

# 当前使用的材质ID
var current_material_id: int = 1
# 材质预设名称列表
var preset_names = ["液态玻璃", "毛玻璃", "水晶玻璃", "极光玻璃"]

# 目标精灵节点
var target_sprite: Sprite2D = null

##
# 初始化材质管理器
# @param sprite: Sprite2D - 目标精灵节点
##
func init(sprite: Sprite2D):
	target_sprite = sprite

##
# 应用材质预设到精灵
# @param preset: Dictionary - 材质预设字典
# @param material_id: int - 材质ID（用于选择着色器类型）
##
func apply_preset(preset: Dictionary, material_id: int):
	if not preset:
		print("[材质] 错误：未指定预设")
		return
	
	if not target_sprite:
		print("[材质] 错误：未设置目标精灵")
		return
	
	current_material_id = material_id
	
	var glass_color = preset.get("glass_color", Color(0.5, 0.5, 0.5, 0.5))
	var edge_glow = preset.get("edge_glow", 0.5)
	var highlight_intensity = preset.get("highlight_intensity", 0.8)
	var liquid_wobble = preset.get("liquid_wobble", 0.2)
	var wobble_speed = preset.get("wobble_speed", 1.0)
	var frost_intensity = preset.get("frost_intensity", 0.7)
	var noise_scale = preset.get("noise_scale", 0.5)
	var preset_name = preset.get("name", "未知材质")
	
	var material = ShaderMaterial.new()
	
	if material_id == 2:
		material.shader = frosted_shader
		material.set_shader_parameter("tint_color", Vector4(glass_color.r, glass_color.g, glass_color.b, glass_color.a))
		material.set_shader_parameter("frost_intensity", frost_intensity)
		material.set_shader_parameter("noise_scale", noise_scale)
		material.set_shader_parameter("opacity", glass_color.a)
	else:
		material.shader = liquid_shader
		material.set_shader_parameter("glass_color", Vector4(glass_color.r, glass_color.g, glass_color.b, glass_color.a))
		material.set_shader_parameter("edge_glow", edge_glow)
		material.set_shader_parameter("highlight_intensity", highlight_intensity)
		material.set_shader_parameter("liquid_wobble", liquid_wobble)
		material.set_shader_parameter("wobble_speed", wobble_speed)
	
	target_sprite.material = material
	print("[材质] 已应用预设: ", preset_name)

##
# 获取当前材质名称
# @return String - 当前材质的中文名称
##
func get_current_material_name() -> String:
	if current_material_id >= 1 and current_material_id <= 4:
		return preset_names[current_material_id - 1]
	return "未知材质"

##
# 获取材质预设名称列表
# @return Array - 材质名称数组
##
func get_preset_names() -> Array:
	return preset_names
