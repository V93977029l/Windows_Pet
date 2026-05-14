extends Node2D

@onready var config = preload("res://config/PetConfig.gd").new()
@onready var drag_script = preload("res://pet_drag.gd").new()
@onready var passthrough_manager = preload("res://addons/mouse_passthrough/mouse_passthrough.gd").new()
@onready var mouse_manager = preload("res://pet_mouse_manager.gd").new()
@onready var pet_sprite: Sprite2D = $Sprite2D

@onready var liquid_shader: Shader = preload("res://assets/shaders/liquid_glass.gdshader")
@onready var frosted_shader: Shader = preload("res://assets/shaders/frosted_glass.gdshader")

var current_material_id: int = 1
var preset_names = ["液态玻璃", "毛玻璃", "水晶玻璃", "极光玻璃"]

func _ready():
	print("✅ [桌宠] ====== 桌宠主程序初始化完成 ========")
	config.print_config()
	
	init_materials()
	init_window()
	center_sprite()
	
	drag_script.init(self)
	passthrough_manager.init(self)
	mouse_manager.init(self, pet_sprite, passthrough_manager)

func init_materials():
	current_material_id = config.current_material
	var preset = config.load_preset(current_material_id)
	apply_preset(preset)

func apply_preset(preset: Dictionary):
	if not preset:
		print("[材质] 错误：未指定预设")
		return
	
	var glass_color = preset.get("glass_color", Color(0.5, 0.5, 0.5, 0.5))
	var edge_glow = preset.get("edge_glow", 0.5)
	var highlight_intensity = preset.get("highlight_intensity", 0.8)
	var liquid_wobble = preset.get("liquid_wobble", 0.2)
	var wobble_speed = preset.get("wobble_speed", 1.0)
	var frost_intensity = preset.get("frost_intensity", 0.7)
	var noise_scale = preset.get("noise_scale", 0.5)
	var preset_name = preset.get("name", "未知材质")
	
	var material = ShaderMaterial.new()
	
	if current_material_id == 2:
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
	
	pet_sprite.material = material
	print("[材质] 已应用预设: ", preset_name)

func init_window():
	var window = get_window()
	window.always_on_top = config.window_always_on_top
	
	print("📌 [窗口] 窗口尺寸：", window.size, "，位置：", window.position)
	print("📌 [窗口] 窗口属性 - 透明：", window.transparent)
	print("📌 [窗口] 窗口属性 - 置顶：", window.always_on_top)

func center_sprite():
	if pet_sprite:
		var screen_size_i: Vector2i = DisplayServer.screen_get_size()
		var screen_size: Vector2 = Vector2(screen_size_i.x, screen_size_i.y)
		
		var target_x: float = screen_size.x / 2
		var target_y: float = screen_size.y / 2
		
		if config.window_initial_x >= 0:
			target_x = config.window_initial_x
		if config.window_initial_y >= 0:
			target_y = config.window_initial_y
		
		pet_sprite.global_position = Vector2(target_x, target_y)
		pet_sprite.scale = Vector2(config.pet_scale, config.pet_scale)
		
		print("[精灵] 精灵全局位置：", pet_sprite.global_position)
		print("[精灵] 精灵缩放大小：", config.pet_scale)

func toggle_material():
	current_material_id = (current_material_id % 4) + 1
	config.current_material = current_material_id
	var preset = config.load_preset(current_material_id)
	apply_preset(preset)
	config.save_config()

func get_current_material_name() -> String:
	if current_material_id >= 1 and current_material_id <= 4:
		return preset_names[current_material_id - 1]
	return "未知材质"

func _process(_delta):
	drag_script.update_drag()
	mouse_manager.update_mouse_passthrough()

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	drag_script.handle_area_input_event(event)
