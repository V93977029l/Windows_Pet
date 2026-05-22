#include "liquid_glass.h"
#include "sdf_utils.h"

using namespace godot;

void LiquidGlass::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_ref_thickness", "value"), &LiquidGlass::set_ref_thickness);
    ClassDB::bind_method(D_METHOD("get_ref_thickness"), &LiquidGlass::get_ref_thickness);
    
    ClassDB::bind_method(D_METHOD("set_ref_factor", "value"), &LiquidGlass::set_ref_factor);
    ClassDB::bind_method(D_METHOD("get_ref_factor"), &LiquidGlass::get_ref_factor);
    
    ClassDB::bind_method(D_METHOD("set_ref_dispersion", "value"), &LiquidGlass::set_ref_dispersion);
    ClassDB::bind_method(D_METHOD("get_ref_dispersion"), &LiquidGlass::get_ref_dispersion);
    
    ClassDB::bind_method(D_METHOD("set_ref_fresnel_range", "value"), &LiquidGlass::set_ref_fresnel_range);
    ClassDB::bind_method(D_METHOD("get_ref_fresnel_range"), &LiquidGlass::get_ref_fresnel_range);
    
    ClassDB::bind_method(D_METHOD("set_ref_fresnel_hardness", "value"), &LiquidGlass::set_ref_fresnel_hardness);
    ClassDB::bind_method(D_METHOD("get_ref_fresnel_hardness"), &LiquidGlass::get_ref_fresnel_hardness);
    
    ClassDB::bind_method(D_METHOD("set_ref_fresnel_factor", "value"), &LiquidGlass::set_ref_fresnel_factor);
    ClassDB::bind_method(D_METHOD("get_ref_fresnel_factor"), &LiquidGlass::get_ref_fresnel_factor);
    
    ClassDB::bind_method(D_METHOD("set_glare_range", "value"), &LiquidGlass::set_glare_range);
    ClassDB::bind_method(D_METHOD("get_glare_range"), &LiquidGlass::get_glare_range);
    
    ClassDB::bind_method(D_METHOD("set_glare_hardness", "value"), &LiquidGlass::set_glare_hardness);
    ClassDB::bind_method(D_METHOD("get_glare_hardness"), &LiquidGlass::get_glare_hardness);
    
    ClassDB::bind_method(D_METHOD("set_glare_convergence", "value"), &LiquidGlass::set_glare_convergence);
    ClassDB::bind_method(D_METHOD("get_glare_convergence"), &LiquidGlass::get_glare_convergence);
    
    ClassDB::bind_method(D_METHOD("set_glare_opposite_factor", "value"), &LiquidGlass::set_glare_opposite_factor);
    ClassDB::bind_method(D_METHOD("get_glare_opposite_factor"), &LiquidGlass::get_glare_opposite_factor);
    
    ClassDB::bind_method(D_METHOD("set_glare_factor", "value"), &LiquidGlass::set_glare_factor);
    ClassDB::bind_method(D_METHOD("get_glare_factor"), &LiquidGlass::get_glare_factor);
    
    ClassDB::bind_method(D_METHOD("set_glare_angle", "value"), &LiquidGlass::set_glare_angle);
    ClassDB::bind_method(D_METHOD("get_glare_angle"), &LiquidGlass::get_glare_angle);
    
    ClassDB::bind_method(D_METHOD("set_blur_radius", "value"), &LiquidGlass::set_blur_radius);
    ClassDB::bind_method(D_METHOD("get_blur_radius"), &LiquidGlass::get_blur_radius);
    
    ClassDB::bind_method(D_METHOD("set_blur_edge", "value"), &LiquidGlass::set_blur_edge);
    ClassDB::bind_method(D_METHOD("get_blur_edge"), &LiquidGlass::get_blur_edge);
    
    ClassDB::bind_method(D_METHOD("set_tint", "value"), &LiquidGlass::set_tint);
    ClassDB::bind_method(D_METHOD("get_tint"), &LiquidGlass::get_tint);
    
    ClassDB::bind_method(D_METHOD("set_shape_width", "value"), &LiquidGlass::set_shape_width);
    ClassDB::bind_method(D_METHOD("get_shape_width"), &LiquidGlass::get_shape_width);
    
    ClassDB::bind_method(D_METHOD("set_shape_height", "value"), &LiquidGlass::set_shape_height);
    ClassDB::bind_method(D_METHOD("get_shape_height"), &LiquidGlass::get_shape_height);
    
    ClassDB::bind_method(D_METHOD("set_shape_radius", "value"), &LiquidGlass::set_shape_radius);
    ClassDB::bind_method(D_METHOD("get_shape_radius"), &LiquidGlass::get_shape_radius);
    
    ClassDB::bind_method(D_METHOD("set_shape_roundness", "value"), &LiquidGlass::set_shape_roundness);
    ClassDB::bind_method(D_METHOD("get_shape_roundness"), &LiquidGlass::get_shape_roundness);
    
    ClassDB::bind_method(D_METHOD("set_merge_rate", "value"), &LiquidGlass::set_merge_rate);
    ClassDB::bind_method(D_METHOD("get_merge_rate"), &LiquidGlass::get_merge_rate);
    
    ClassDB::bind_method(D_METHOD("set_show_shape1", "value"), &LiquidGlass::set_show_shape1);
    ClassDB::bind_method(D_METHOD("get_show_shape1"), &LiquidGlass::get_show_shape1);
    
    ClassDB::bind_method(D_METHOD("compute_normal", "p1", "p2", "p", "dpr", "resolutionY"), &LiquidGlass::compute_normal);
    ClassDB::bind_method(D_METHOD("compute_refraction_edge_factor", "sdfValue", "resolutionY"), &LiquidGlass::compute_refraction_edge_factor);
    ClassDB::bind_method(D_METHOD("compute_fresnel_factor", "sdfValue", "resolutionY"), &LiquidGlass::compute_fresnel_factor);
    ClassDB::bind_method(D_METHOD("compute_glare_geometry_factor", "sdfValue", "resolutionY"), &LiquidGlass::compute_glare_geometry_factor);
    ClassDB::bind_method(D_METHOD("compute_glare_angle_factor", "normal"), &LiquidGlass::compute_glare_angle_factor);
    ClassDB::bind_method(D_METHOD("compute_sdf", "p1", "p2", "p", "dpr", "resolutionY"), &LiquidGlass::compute_sdf);
    
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ref_thickness", PROPERTY_HINT_RANGE, "1,80,0.01"), "set_ref_thickness", "get_ref_thickness");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ref_factor", PROPERTY_HINT_RANGE, "1,4,0.01"), "set_ref_factor", "get_ref_factor");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ref_dispersion", PROPERTY_HINT_RANGE, "0,50,0.01"), "set_ref_dispersion", "get_ref_dispersion");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ref_fresnel_range", PROPERTY_HINT_RANGE, "0,100,0.01"), "set_ref_fresnel_range", "get_ref_fresnel_range");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ref_fresnel_hardness", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_ref_fresnel_hardness", "get_ref_fresnel_hardness");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ref_fresnel_factor", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_ref_fresnel_factor", "get_ref_fresnel_factor");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "glare_range", PROPERTY_HINT_RANGE, "0,100,0.01"), "set_glare_range", "get_glare_range");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "glare_hardness", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_glare_hardness", "get_glare_hardness");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "glare_convergence", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_glare_convergence", "get_glare_convergence");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "glare_opposite_factor", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_glare_opposite_factor", "get_glare_opposite_factor");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "glare_factor", PROPERTY_HINT_RANGE, "0,1.2,0.01"), "set_glare_factor", "get_glare_factor");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "glare_angle", PROPERTY_HINT_RANGE, "-3.14159,3.14159,0.01"), "set_glare_angle", "get_glare_angle");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "blur_radius", PROPERTY_HINT_RANGE, "1,200,1"), "set_blur_radius", "get_blur_radius");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "blur_edge"), "set_blur_edge", "get_blur_edge");
    ADD_PROPERTY(PropertyInfo(Variant::COLOR, "tint"), "set_tint", "get_tint");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shape_width", PROPERTY_HINT_RANGE, "20,800,1"), "set_shape_width", "get_shape_width");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shape_height", PROPERTY_HINT_RANGE, "20,800,1"), "set_shape_height", "get_shape_height");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shape_radius", PROPERTY_HINT_RANGE, "1,100,0.1"), "set_shape_radius", "get_shape_radius");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shape_roundness", PROPERTY_HINT_RANGE, "2,7,0.01"), "set_shape_roundness", "get_shape_roundness");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "merge_rate", PROPERTY_HINT_RANGE, "0,0.3,0.01"), "set_merge_rate", "get_merge_rate");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "show_shape1"), "set_show_shape1", "get_show_shape1");
}

LiquidGlass::LiquidGlass() {
}

LiquidGlass::~LiquidGlass() {
}

void LiquidGlass::set_ref_thickness(float value) { refThickness = value; }
float LiquidGlass::get_ref_thickness() const { return refThickness; }

void LiquidGlass::set_ref_factor(float value) { refFactor = value; }
float LiquidGlass::get_ref_factor() const { return refFactor; }

void LiquidGlass::set_ref_dispersion(float value) { refDispersion = value; }
float LiquidGlass::get_ref_dispersion() const { return refDispersion; }

void LiquidGlass::set_ref_fresnel_range(float value) { refFresnelRange = value; }
float LiquidGlass::get_ref_fresnel_range() const { return refFresnelRange; }

void LiquidGlass::set_ref_fresnel_hardness(float value) { refFresnelHardness = value; }
float LiquidGlass::get_ref_fresnel_hardness() const { return refFresnelHardness; }

void LiquidGlass::set_ref_fresnel_factor(float value) { refFresnelFactor = value; }
float LiquidGlass::get_ref_fresnel_factor() const { return refFresnelFactor; }

void LiquidGlass::set_glare_range(float value) { glareRange = value; }
float LiquidGlass::get_glare_range() const { return glareRange; }

void LiquidGlass::set_glare_hardness(float value) { glareHardness = value; }
float LiquidGlass::get_glare_hardness() const { return glareHardness; }

void LiquidGlass::set_glare_convergence(float value) { glareConvergence = value; }
float LiquidGlass::get_glare_convergence() const { return glareConvergence; }

void LiquidGlass::set_glare_opposite_factor(float value) { glareOppositeFactor = value; }
float LiquidGlass::get_glare_opposite_factor() const { return glareOppositeFactor; }

void LiquidGlass::set_glare_factor(float value) { glareFactor = value; }
float LiquidGlass::get_glare_factor() const { return glareFactor; }

void LiquidGlass::set_glare_angle(float value) { glareAngle = value; }
float LiquidGlass::get_glare_angle() const { return glareAngle; }

void LiquidGlass::set_blur_radius(float value) { blurRadius = value; }
float LiquidGlass::get_blur_radius() const { return blurRadius; }

void LiquidGlass::set_blur_edge(bool value) { blurEdge = value; }
bool LiquidGlass::get_blur_edge() const { return blurEdge; }

void LiquidGlass::set_tint(const Color& value) { tint = value; }
Color LiquidGlass::get_tint() const { return tint; }

void LiquidGlass::set_shape_width(float value) { shapeWidth = value; }
float LiquidGlass::get_shape_width() const { return shapeWidth; }

void LiquidGlass::set_shape_height(float value) { shapeHeight = value; }
float LiquidGlass::get_shape_height() const { return shapeHeight; }

void LiquidGlass::set_shape_radius(float value) { shapeRadius = value; }
float LiquidGlass::get_shape_radius() const { return shapeRadius; }

void LiquidGlass::set_shape_roundness(float value) { shapeRoundness = value; }
float LiquidGlass::get_shape_roundness() const { return shapeRoundness; }

void LiquidGlass::set_merge_rate(float value) { mergeRate = value; }
float LiquidGlass::get_merge_rate() const { return mergeRate; }

void LiquidGlass::set_show_shape1(bool value) { showShape1 = value; }
bool LiquidGlass::get_show_shape1() const { return showShape1; }

Vector2 LiquidGlass::compute_normal(const Vector2& p1, const Vector2& p2, const Vector2& p, float dpr, float resolutionY) const {
    return LiquidGlassUtils::getNormal(p1, p2, p, shapeWidth, shapeHeight, shapeRadius, shapeRoundness, mergeRate, dpr, resolutionY, showShape1 ? 1 : 0);
}

float LiquidGlass::compute_refraction_edge_factor(float sdfValue, float resolutionY) const {
    return LiquidGlassUtils::computeRefractionEdgeFactor(sdfValue, refThickness, refFactor, resolutionY);
}

float LiquidGlass::compute_fresnel_factor(float sdfValue, float resolutionY) const {
    return LiquidGlassUtils::computeFresnelFactor(sdfValue, refFresnelRange, refFresnelHardness, resolutionY);
}

float LiquidGlass::compute_glare_geometry_factor(float sdfValue, float resolutionY) const {
    return LiquidGlassUtils::computeGlareGeometryFactor(sdfValue, glareRange, glareHardness, resolutionY);
}

float LiquidGlass::compute_glare_angle_factor(const Vector2& normal) const {
    return LiquidGlassUtils::computeGlareAngleFactor(normal, glareAngle);
}

float LiquidGlass::compute_sdf(const Vector2& p1, const Vector2& p2, const Vector2& p, float dpr, float resolutionY) const {
    return LiquidGlassUtils::mainSDF(p1, p2, p, shapeWidth, shapeHeight, shapeRadius, shapeRoundness, mergeRate, dpr, resolutionY, showShape1 ? 1 : 0);
}