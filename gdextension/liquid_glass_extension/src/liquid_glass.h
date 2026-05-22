#ifndef LIQUID_GLASS_H
#define LIQUID_GLASS_H

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/color.hpp>

using namespace godot;

class LiquidGlass : public Resource {
    GDCLASS(LiquidGlass, Resource)
    
private:
    float refThickness = 20.0f;
    float refFactor = 1.4f;
    float refDispersion = 7.0f;
    float refFresnelRange = 30.0f;
    float refFresnelHardness = 0.2f;
    float refFresnelFactor = 0.2f;
    
    float glareRange = 30.0f;
    float glareHardness = 0.2f;
    float glareConvergence = 0.5f;
    float glareOppositeFactor = 0.8f;
    float glareFactor = 0.9f;
    float glareAngle = -Math_PI / 4.0f;
    
    float blurRadius = 1.0f;
    bool blurEdge = true;
    
    Color tint = Color(1.0f, 1.0f, 1.0f, 0.0f);
    
    float shapeWidth = 200.0f;
    float shapeHeight = 200.0f;
    float shapeRadius = 80.0f;
    float shapeRoundness = 5.0f;
    float mergeRate = 0.05f;
    bool showShape1 = true;
    
protected:
    static void _bind_methods();
    
public:
    LiquidGlass();
    ~LiquidGlass();
    
    void set_ref_thickness(float value);
    float get_ref_thickness() const;
    
    void set_ref_factor(float value);
    float get_ref_factor() const;
    
    void set_ref_dispersion(float value);
    float get_ref_dispersion() const;
    
    void set_ref_fresnel_range(float value);
    float get_ref_fresnel_range() const;
    
    void set_ref_fresnel_hardness(float value);
    float get_ref_fresnel_hardness() const;
    
    void set_ref_fresnel_factor(float value);
    float get_ref_fresnel_factor() const;
    
    void set_glare_range(float value);
    float get_glare_range() const;
    
    void set_glare_hardness(float value);
    float get_glare_hardness() const;
    
    void set_glare_convergence(float value);
    float get_glare_convergence() const;
    
    void set_glare_opposite_factor(float value);
    float get_glare_opposite_factor() const;
    
    void set_glare_factor(float value);
    float get_glare_factor() const;
    
    void set_glare_angle(float value);
    float get_glare_angle() const;
    
    void set_blur_radius(float value);
    float get_blur_radius() const;
    
    void set_blur_edge(bool value);
    bool get_blur_edge() const;
    
    void set_tint(const Color& value);
    Color get_tint() const;
    
    void set_shape_width(float value);
    float get_shape_width() const;
    
    void set_shape_height(float value);
    float get_shape_height() const;
    
    void set_shape_radius(float value);
    float get_shape_radius() const;
    
    void set_shape_roundness(float value);
    float get_shape_roundness() const;
    
    void set_merge_rate(float value);
    float get_merge_rate() const;
    
    void set_show_shape1(bool value);
    bool get_show_shape1() const;
    
    Vector2 compute_normal(const Vector2& p1, const Vector2& p2, const Vector2& p, float dpr, float resolutionY) const;
    
    float compute_refraction_edge_factor(float sdfValue, float resolutionY) const;
    
    float compute_fresnel_factor(float sdfValue, float resolutionY) const;
    
    float compute_glare_geometry_factor(float sdfValue, float resolutionY) const;
    
    float compute_glare_angle_factor(const Vector2& normal) const;
    
    float compute_sdf(const Vector2& p1, const Vector2& p2, const Vector2& p, float dpr, float resolutionY) const;
};

#endif
