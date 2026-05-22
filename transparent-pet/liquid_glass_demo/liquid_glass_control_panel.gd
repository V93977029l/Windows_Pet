extends PanelContainer

@onready var renderer: Node2D = get_parent().get_node("LiquidGlassRenderer")

@onready var ref_thickness_slider: HSlider = $VBoxContainer/Refraction/RefThickness/HSlider
@onready var ref_factor_slider: HSlider = $VBoxContainer/Refraction/RefFactor/HSlider
@onready var ref_dispersion_slider: HSlider = $VBoxContainer/Refraction/RefDispersion/HSlider
@onready var ref_fresnel_range_slider: HSlider = $VBoxContainer/Refraction/FresnelRange/HSlider
@onready var ref_fresnel_hardness_slider: HSlider = $VBoxContainer/Refraction/FresnelHardness/HSlider
@onready var ref_fresnel_factor_slider: HSlider = $VBoxContainer/Refraction/FresnelFactor/HSlider

@onready var glare_range_slider: HSlider = $VBoxContainer/Glare/GlareRange/HSlider
@onready var glare_hardness_slider: HSlider = $VBoxContainer/Glare/GlareHardness/HSlider
@onready var glare_factor_slider: HSlider = $VBoxContainer/Glare/GlareFactor/HSlider
@onready var glare_convergence_slider: HSlider = $VBoxContainer/Glare/GlareConvergence/HSlider
@onready var glare_opposite_factor_slider: HSlider = $VBoxContainer/Glare/GlareOpposite/HSlider
@onready var glare_angle_slider: HSlider = $VBoxContainer/Glare/GlareAngle/HSlider

@onready var blur_radius_slider: HSlider = $VBoxContainer/Blur/BlurRadius/HSlider
@onready var blur_edge_check: CheckBox = $VBoxContainer/Blur/BlurEdge/CheckBox

@onready var tint_color_picker: ColorPickerButton = $VBoxContainer/Tint/TintColor/ColorPickerButton
@onready var tint_alpha_slider: HSlider = $VBoxContainer/Tint/TintAlpha/HSlider

@onready var shape_width_slider: HSlider = $VBoxContainer/Shape/ShapeWidth/HSlider
@onready var shape_height_slider: HSlider = $VBoxContainer/Shape/ShapeHeight/HSlider
@onready var shape_radius_slider: HSlider = $VBoxContainer/Shape/ShapeRadius/HSlider
@onready var shape_roundness_slider: HSlider = $VBoxContainer/Shape/ShapeRoundness/HSlider
@onready var merge_rate_slider: HSlider = $VBoxContainer/Shape/MergeRate/HSlider
@onready var show_shape1_check: CheckBox = $VBoxContainer/Shape/ShowShape1/CheckBox

@onready var shadow_expand_slider: HSlider = $VBoxContainer/Shadow/ShadowExpand/HSlider
@onready var shadow_factor_slider: HSlider = $VBoxContainer/Shadow/ShadowFactor/HSlider
@onready var shadow_position_x_slider: HSlider = $VBoxContainer/Shadow/ShadowPositionX/HSlider
@onready var shadow_position_y_slider: HSlider = $VBoxContainer/Shadow/ShadowPositionY/HSlider

@onready var bg_type_combo: OptionButton = $VBoxContainer/Background/BgType/OptionButton

func _ready():
    # 初始化背景选项
    bg_type_combo.clear()
    bg_type_combo.add_item("Chessboard")
    bg_type_combo.add_item("Split")
    bg_type_combo.add_item("Gradient")
    bg_type_combo.add_item("Transparent")  # 添加透明选项
    
    if renderer:
        ref_thickness_slider.value = renderer.ref_thickness
        ref_factor_slider.value = renderer.ref_factor
        ref_dispersion_slider.value = renderer.ref_dispersion
        ref_fresnel_range_slider.value = renderer.ref_fresnel_range
        ref_fresnel_hardness_slider.value = renderer.ref_fresnel_hardness * 100
        ref_fresnel_factor_slider.value = renderer.ref_fresnel_factor * 100
        
        glare_range_slider.value = renderer.glare_range
        glare_hardness_slider.value = renderer.glare_hardness * 100
        glare_factor_slider.value = renderer.glare_factor * 100
        glare_convergence_slider.value = renderer.glare_convergence * 100
        glare_opposite_factor_slider.value = renderer.glare_opposite_factor * 100
        glare_angle_slider.value = renderer.glare_angle
        
        blur_radius_slider.value = renderer.blur_radius
        blur_edge_check.button_pressed = renderer.blur_edge
        
        tint_color_picker.color = renderer.tint
        tint_alpha_slider.value = renderer.tint_alpha * 100
        
        shape_width_slider.value = renderer.shape_width
        shape_height_slider.value = renderer.shape_height
        shape_radius_slider.value = renderer.shape_radius
        shape_roundness_slider.value = renderer.shape_roundness
        merge_rate_slider.value = renderer.merge_rate * 100
        show_shape1_check.button_pressed = renderer.show_shape1
        
        shadow_expand_slider.value = renderer.shadow_expand
        shadow_factor_slider.value = renderer.shadow_factor * 100
        shadow_position_x_slider.value = renderer.shadow_position.x
        shadow_position_y_slider.value = renderer.shadow_position.y
        
        bg_type_combo.selected = renderer.bg_type

func _on_ref_thickness_changed(value: float):
    if renderer:
        renderer.ref_thickness = value
        renderer.update_all_uniforms()

func _on_ref_factor_changed(value: float):
    if renderer:
        renderer.ref_factor = value
        renderer.update_all_uniforms()

func _on_ref_dispersion_changed(value: float):
    if renderer:
        renderer.ref_dispersion = value
        renderer.update_all_uniforms()

func _on_ref_fresnel_range_changed(value: float):
    if renderer:
        renderer.ref_fresnel_range = value
        renderer.update_all_uniforms()

func _on_ref_fresnel_hardness_changed(value: float):
    if renderer:
        renderer.ref_fresnel_hardness = value / 100.0
        renderer.update_all_uniforms()

func _on_ref_fresnel_factor_changed(value: float):
    if renderer:
        renderer.ref_fresnel_factor = value / 100.0
        renderer.update_all_uniforms()

func _on_glare_range_changed(value: float):
    if renderer:
        renderer.glare_range = value
        renderer.update_all_uniforms()

func _on_glare_hardness_changed(value: float):
    if renderer:
        renderer.glare_hardness = value / 100.0
        renderer.update_all_uniforms()

func _on_glare_factor_changed(value: float):
    if renderer:
        renderer.glare_factor = value / 100.0
        renderer.update_all_uniforms()

func _on_glare_convergence_changed(value: float):
    if renderer:
        renderer.glare_convergence = value / 100.0
        renderer.update_all_uniforms()

func _on_glare_opposite_factor_changed(value: float):
    if renderer:
        renderer.glare_opposite_factor = value / 100.0
        renderer.update_all_uniforms()

func _on_glare_angle_changed(value: float):
    if renderer:
        renderer.glare_angle = value
        renderer.update_all_uniforms()

func _on_blur_radius_changed(value: float):
    if renderer:
        renderer.blur_radius = value
        renderer.update_all_uniforms()

func _on_blur_edge_toggled(value: bool):
    if renderer:
        renderer.blur_edge = value
        renderer.update_all_uniforms()

func _on_tint_color_changed(value: Color):
    if renderer:
        renderer.tint = value
        renderer.update_all_uniforms()

func _on_tint_alpha_changed(value: float):
    if renderer:
        renderer.tint_alpha = value / 100.0
        renderer.update_all_uniforms()

func _on_shape_width_changed(value: float):
    if renderer:
        renderer.shape_width = value
        renderer.update_all_uniforms()

func _on_shape_height_changed(value: float):
    if renderer:
        renderer.shape_height = value
        renderer.update_all_uniforms()

func _on_shape_radius_changed(value: float):
    if renderer:
        renderer.shape_radius = value
        renderer.update_all_uniforms()

func _on_shape_roundness_changed(value: float):
    if renderer:
        renderer.shape_roundness = value
        renderer.update_all_uniforms()

func _on_merge_rate_changed(value: float):
    if renderer:
        renderer.merge_rate = value / 100.0
        renderer.update_all_uniforms()

func _on_show_shape1_toggled(value: bool):
    if renderer:
        renderer.show_shape1 = value
        renderer.update_all_uniforms()

func _on_shadow_expand_changed(value: float):
    if renderer:
        renderer.shadow_expand = value
        renderer.update_all_uniforms()

func _on_shadow_factor_changed(value: float):
    if renderer:
        renderer.shadow_factor = value / 100.0
        renderer.update_all_uniforms()

func _on_shadow_position_x_changed(value: float):
    if renderer:
        renderer.shadow_position.x = value
        renderer.update_all_uniforms()

func _on_shadow_position_y_changed(value: float):
    if renderer:
        renderer.shadow_position.y = value
        renderer.update_all_uniforms()

func _on_bg_type_changed(index: int):
    if renderer:
        renderer.bg_type = index
        renderer.update_all_uniforms()