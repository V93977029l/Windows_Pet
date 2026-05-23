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

@export var merge_rate: float = 0.05

@export var shadow_expand: float = 25.0
@export var shadow_factor: float = 0.15
@export var shadow_position: Vector2 = Vector2(0, -10)

@export var bg_type: int = 0

var mouse_position: Vector2 = Vector2.ZERO
var mouse_spring: Vector2 = Vector2.ZERO
var blur_weights: PackedFloat32Array = PackedFloat32Array()

var item_manager: GlassItemManager = GlassItemManager.new()
const MAX_ITEMS: int = 3

func _ready():
	main_texture_rect.texture = main_viewport.get_texture()
	
	# Note: texture_filter is set on TextureRect node in .tscn file (MainTexture has texture_filter = 2)
	
	update_viewport_sizes()
	update_blur_weights()
	
	init_default_items()
	update_items_uniforms()
	
	get_viewport().size_changed.connect(_on_viewport_resize)

func init_default_items():
	var dpr: float = get_tree().root.content_scale_factor
	var viewport_size = Vector2(get_viewport().size.x * dpr, get_viewport().size.y * dpr)
	item_manager.init_default_items(viewport_size)

func update_viewport_sizes():
	var viewport_size: Vector2i = get_viewport().size
	var dpr: float = get_tree().root.content_scale_factor
	
	bg_viewport.size = Vector2i(int(viewport_size.x * dpr), int(viewport_size.y * dpr))
	vblur_viewport.size = Vector2i(int(viewport_size.x * dpr), int(viewport_size.y * dpr))
	hblur_viewport.size = Vector2i(int(viewport_size.x * dpr), int(viewport_size.y * dpr))
	main_viewport.size = Vector2i(int(viewport_size.x * dpr), int(viewport_size.y * dpr))

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
	var dpr: float = get_tree().root.content_scale_factor
	var resolution: Vector2 = Vector2(get_viewport().size.x * dpr, get_viewport().size.y * dpr)

	bg_material.set_shader_parameter("u_resolution", resolution)
	bg_material.set_shader_parameter("u_dpr", dpr)
	bg_material.set_shader_parameter("u_time", Time.get_ticks_msec() / 1000.0)
	bg_material.set_shader_parameter("u_shadowExpand", shadow_expand)
	bg_material.set_shader_parameter("u_shadowFactor", shadow_factor)
	bg_material.set_shader_parameter("u_shadowPosition", shadow_position)
	bg_material.set_shader_parameter("u_bgType", bg_type)
	bg_material.set_shader_parameter("u_shapeTexture", main_viewport.get_texture())

	vblur_material.set_shader_parameter("u_resolution", resolution)
	vblur_material.set_shader_parameter("u_dpr", dpr)
	vblur_material.set_shader_parameter("u_blurRadius", blur_radius)
	vblur_material.set_shader_parameter("u_blurWeights", blur_weights)
	vblur_material.set_shader_parameter("u_vertical", true)
	vblur_material.set_shader_parameter("u_prevPassTexture", bg_viewport.get_texture())

	hblur_material.set_shader_parameter("u_resolution", resolution)
	hblur_material.set_shader_parameter("u_dpr", dpr)
	hblur_material.set_shader_parameter("u_blurRadius", blur_radius)
	hblur_material.set_shader_parameter("u_blurWeights", blur_weights)
	hblur_material.set_shader_parameter("u_vertical", false)
	hblur_material.set_shader_parameter("u_prevPassTexture", vblur_viewport.get_texture())

	main_material.set_shader_parameter("u_resolution", resolution)
	main_material.set_shader_parameter("u_dpr", dpr)
	main_material.set_shader_parameter("u_mouse", mouse_position)
	main_material.set_shader_parameter("u_mouseSpring", mouse_spring)
	main_material.set_shader_parameter("u_mergeRate", merge_rate)
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
	main_material.set_shader_parameter("STEP", 9)
	main_material.set_shader_parameter("u_bg", bg_viewport.get_texture())
	main_material.set_shader_parameter("u_blurredBg", hblur_viewport.get_texture())
	
	update_items_uniforms()

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
	
	update_items_uniforms()

func update_items_uniforms():
	var items = item_manager.get_items()
	
	var positions: PackedVector2Array = PackedVector2Array()
	var widths: PackedFloat32Array = PackedFloat32Array()
	var heights: PackedFloat32Array = PackedFloat32Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var roundness: PackedFloat32Array = PackedFloat32Array()
	var shapeTypes: PackedFloat32Array = PackedFloat32Array()
	var enabled: PackedFloat32Array = PackedFloat32Array()
	var scales: PackedFloat32Array = PackedFloat32Array()
	
	for i in range(MAX_ITEMS):
		if i < items.size():
			var item = items[i]
			positions.append(item.position)
			widths.append(item.width)
			heights.append(item.height)
			radii.append(item.radius)
			roundness.append(item.roundness)
			shapeTypes.append(float(item.shape_type))
			enabled.append(1.0 if item.enabled else 0.0)
			scales.append(item.scale)
		else:
			positions.append(Vector2.ZERO)
			widths.append(0.0)
			heights.append(0.0)
			radii.append(0.0)
			roundness.append(0.0)
			shapeTypes.append(0.0)
			enabled.append(0.0)
			scales.append(0.0)
	
	bg_material.set_shader_parameter("u_itemPositions", positions)
	bg_material.set_shader_parameter("u_itemWidths", widths)
	bg_material.set_shader_parameter("u_itemHeights", heights)
	bg_material.set_shader_parameter("u_itemRadii", radii)
	bg_material.set_shader_parameter("u_itemRoundness", roundness)
	bg_material.set_shader_parameter("u_itemShapeTypes", shapeTypes)
	bg_material.set_shader_parameter("u_itemEnabled", enabled)
	bg_material.set_shader_parameter("u_itemScales", scales)
	
	main_material.set_shader_parameter("u_itemPositions", positions)
	main_material.set_shader_parameter("u_itemWidths", widths)
	main_material.set_shader_parameter("u_itemHeights", heights)
	main_material.set_shader_parameter("u_itemRadii", radii)
	main_material.set_shader_parameter("u_itemRoundness", roundness)
	main_material.set_shader_parameter("u_itemShapeTypes", shapeTypes)
	main_material.set_shader_parameter("u_itemEnabled", enabled)
	main_material.set_shader_parameter("u_itemScales", scales)

func get_item_manager() -> GlassItemManager:
	return item_manager
