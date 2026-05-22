extends Node2D

@onready var bg_viewport: SubViewport = $RenderLayers/BgViewport
@onready var vblur_viewport: SubViewport = $RenderLayers/VBlurViewport
@onready var hblur_viewport: SubViewport = $RenderLayers/HBlurViewport
@onready var main_viewport: SubViewport = $RenderLayers/MainViewport

@onready var bg_rect: ColorRect = bg_viewport.get_child(0)
@onready var vblur_rect: ColorRect = vblur_viewport.get_child(0)
@onready var hblur_rect: ColorRect = hblur_viewport.get_child(0)
@onready var main_rect: ColorRect = main_viewport.get_child(0)
@onready var main_texture_rect: TextureRect = $MainTexture

@onready var bg_material: ShaderMaterial = bg_rect.material as ShaderMaterial
@onready var vblur_material: ShaderMaterial = vblur_rect.material as ShaderMaterial
@onready var hblur_material: ShaderMaterial = hblur_rect.material as ShaderMaterial
@onready var main_material: ShaderMaterial = main_rect.material as ShaderMaterial

@export var ref_thickness: float = 20.0
@export var ref_factor: float = 1.4
@export var ref_dispersion: float = 7.0
@export var ref_fresnel_range: float = 30.0
@export var ref_fresnel_hardness: float = 0.2
@export var ref_fresnel_factor: float = 0.2

@export var glare_range: float = 30.0
@export var glare_hardness: float = 0.2
@export var glare_convergence: float = 0.5
@export var glare_opposite_factor: float = 0.8
@export var glare_factor: float = 0.9
@export var glare_angle: float = -45.0

@export var blur_radius: float = 1.0
@export var blur_edge: bool = true

@export var tint: Color = Color.WHITE
@export var tint_alpha: float = 0.0

@export var shape_width: float = 200.0
@export var shape_height: float = 200.0
@export var shape_radius: float = 80.0
@export var shape_roundness: float = 5.0
@export var merge_rate: float = 0.05
@export var show_shape1: bool = true

@export var shadow_expand: float = 25.0
@export var shadow_factor: float = 0.15
@export var shadow_position: Vector2 = Vector2(0, -10)

@export var bg_type: int = 3

var mouse_position: Vector2 = Vector2.ZERO
var mouse_spring: Vector2 = Vector2.ZERO
var blur_weights: PackedFloat32Array = PackedFloat32Array()

func _ready():
	main_texture_rect.texture = main_viewport.get_texture()
	
	update_viewport_sizes()
	update_blur_weights()
	update_all_uniforms()
	
	get_viewport().size_changed.connect(_on_viewport_resize)

func update_viewport_sizes():
	var viewport_size: Vector2i = get_viewport().size
	
	bg_viewport.size = viewport_size
	vblur_viewport.size = viewport_size
	hblur_viewport.size = viewport_size
	main_viewport.size = viewport_size

func _on_viewport_resize():
	update_viewport_sizes()
	update_all_uniforms()

func compute_gaussian_kernel(radius: float) -> PackedFloat32Array:
	var sigma: float = radius / 3.0
	var weights: PackedFloat32Array = PackedFloat32Array()
	var total_weight: float = 0.0

	for i in range(int(radius * 2) + 1):
		var x: float = float(i) - radius
		var weight: float = exp(-x * x / (2.0 * sigma * sigma))
		weights.append(weight)
		total_weight += weight

	for i in range(weights.size()):
		weights[i] /= total_weight

	return weights

func update_blur_weights():
	blur_weights = compute_gaussian_kernel(blur_radius)

func update_all_uniforms():
	var dpr: float = 1.0
	var resolution: Vector2 = Vector2(get_viewport().size.x, get_viewport().size.y)

	bg_material.set_shader_parameter("u_resolution", resolution)
	bg_material.set_shader_parameter("u_dpr", dpr)
	bg_material.set_shader_parameter("u_mouse", mouse_position)
	bg_material.set_shader_parameter("u_mouseSpring", mouse_spring)
	bg_material.set_shader_parameter("u_time", Time.get_ticks_msec() / 1000.0)
	bg_material.set_shader_parameter("u_mergeRate", merge_rate)
	bg_material.set_shader_parameter("u_shapeWidth", shape_width)
	bg_material.set_shader_parameter("u_shapeHeight", shape_height)
	bg_material.set_shader_parameter("u_shapeRadius", shape_radius)
	bg_material.set_shader_parameter("u_shapeRoundness", shape_roundness)
	bg_material.set_shader_parameter("u_shadowExpand", shadow_expand)
	bg_material.set_shader_parameter("u_shadowFactor", shadow_factor)
	bg_material.set_shader_parameter("u_shadowPosition", shadow_position)
	bg_material.set_shader_parameter("u_bgType", bg_type)
	bg_material.set_shader_parameter("u_showShape1", 1 if show_shape1 else 0)

	vblur_material.set_shader_parameter("u_resolution", resolution)
	vblur_material.set_shader_parameter("u_dpr", dpr)
	vblur_material.set_shader_parameter("u_blurRadius", blur_radius)
	vblur_material.set_shader_parameter("u_blurWeights", blur_weights)
	vblur_material.set_shader_parameter("u_vertical", true)

	hblur_material.set_shader_parameter("u_resolution", resolution)
	hblur_material.set_shader_parameter("u_dpr", dpr)
	hblur_material.set_shader_parameter("u_blurRadius", blur_radius)
	hblur_material.set_shader_parameter("u_blurWeights", blur_weights)
	hblur_material.set_shader_parameter("u_vertical", false)

	main_material.set_shader_parameter("u_resolution", resolution)
	main_material.set_shader_parameter("u_dpr", dpr)
	main_material.set_shader_parameter("u_mouse", mouse_position)
	main_material.set_shader_parameter("u_mouseSpring", mouse_spring)
	main_material.set_shader_parameter("u_mergeRate", merge_rate)
	main_material.set_shader_parameter("u_shapeWidth", shape_width)
	main_material.set_shader_parameter("u_shapeHeight", shape_height)
	main_material.set_shader_parameter("u_shapeRadius", shape_radius)
	main_material.set_shader_parameter("u_shapeRoundness", shape_roundness)
	main_material.set_shader_parameter("u_tint", Color(tint.r, tint.g, tint.b, tint_alpha))
	main_material.set_shader_parameter("u_refThickness", ref_thickness)
	main_material.set_shader_parameter("u_refFactor", ref_factor)
	main_material.set_shader_parameter("u_refDispersion", ref_dispersion)
	main_material.set_shader_parameter("u_refFresnelRange", ref_fresnel_range)
	main_material.set_shader_parameter("u_refFresnelHardness", ref_fresnel_hardness)
	main_material.set_shader_parameter("u_refFresnelFactor", ref_fresnel_factor)
	main_material.set_shader_parameter("u_glareRange", glare_range)
	main_material.set_shader_parameter("u_glareConvergence", glare_convergence)
	main_material.set_shader_parameter("u_glareOppositeFactor", glare_opposite_factor)
	main_material.set_shader_parameter("u_glareFactor", glare_factor)
	main_material.set_shader_parameter("u_glareHardness", glare_hardness)
	main_material.set_shader_parameter("u_glareAngle", deg_to_rad(glare_angle))
	main_material.set_shader_parameter("u_blurEdge", 1 if blur_edge else 0)
	main_material.set_shader_parameter("u_showShape1", 1 if show_shape1 else 0)
	main_material.set_shader_parameter("STEP", 9)

func set_mouse_position(pos: Vector2):
	mouse_position = pos

func set_mouse_spring(pos: Vector2):
	mouse_spring = pos

func _process(_delta: float):
	bg_material.set_shader_parameter("u_time", Time.get_ticks_msec() / 1000.0)
	bg_material.set_shader_parameter("u_mouse", mouse_position)
	bg_material.set_shader_parameter("u_mouseSpring", mouse_spring)
	main_material.set_shader_parameter("u_mouse", mouse_position)
	main_material.set_shader_parameter("u_mouseSpring", mouse_spring)
	update_blur_weights()

	vblur_material.set_shader_parameter("u_prevPassTexture", bg_viewport.get_texture())
	hblur_material.set_shader_parameter("u_prevPassTexture", vblur_viewport.get_texture())
	main_material.set_shader_parameter("u_blurredBg", hblur_viewport.get_texture())
	main_material.set_shader_parameter("u_bg", bg_viewport.get_texture())
