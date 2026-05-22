#include "sdf_utils.h"
#include <cmath>

namespace LiquidGlassUtils {

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

float sdCircle(const Vector2& p, float r) {
    return p.length() - r;
}

float superellipseCornerSDF(const Vector2& p, float r, float n) {
    Vector2 abs_p = p.abs();
    float v = pow(pow((float)abs_p.x, n) + pow((float)abs_p.y, n), 1.0f / n);
    return v - r;
}

float roundedRectSDF(const Vector2& p, const Vector2& center, float width, float height, float cornerRadius, float roundness) {
    Vector2 local_p = p - center;
    float cr = cornerRadius;
    
    Vector2 d = local_p.abs() - Vector2(width, height) * 0.5f;
    
    float dist;
    
    if (d.x > -cr && d.y > -cr) {
        Vector2 cornerCenter = local_p.sign() * (Vector2(width, height) * 0.5f - Vector2(cr, cr));
        Vector2 cornerP = local_p - cornerCenter;
        dist = superellipseCornerSDF(cornerP, cr, roundness);
    } else {
        dist = godot::Math::min(godot::Math::max(d.x, d.y), 0.0f) + godot::Math::max(d, Vector2(0.0f, 0.0f)).length();
    }
    
    return dist;
}

float smin(float a, float b, float k) {
    float h = godot::Math::clamp(0.5f + 0.5f * (b - a) / k, 0.0f, 1.0f);
    float mix_val = b * (1.0f - h) + a * h;
    return mix_val - k * h * (1.0f - h);
}

float mainSDF(const Vector2& p1, const Vector2& p2, const Vector2& p, float shapeWidth, float shapeHeight, float shapeRadius, float shapeRoundness, float mergeRate, float dpr, float resolutionY, int showShape1) {
    Vector2 p1n = p1 + p / resolutionY;
    Vector2 p2n = p2 + p / resolutionY;
    
    float d1 = (showShape1 == 1) ? sdCircle(p1n, 100.0f * dpr / resolutionY) : 1.0f;
    
    float d2 = roundedRectSDF(
        p2n,
        Vector2(0.0f, 0.0f),
        shapeWidth / resolutionY,
        shapeHeight / resolutionY,
        shapeRadius / resolutionY,
        shapeRoundness
    );
    
    return smin(d1, d2, mergeRate);
}

Vector2 getNormal(const Vector2& p1, const Vector2& p2, const Vector2& p, float shapeWidth, float shapeHeight, float shapeRadius, float shapeRoundness, float mergeRate, float dpr, float resolutionY, int showShape1) {
    const float eps = 0.7071f * 0.0005f;
    Vector2 e1 = Vector2(1.0f, 1.0f);
    Vector2 e2 = Vector2(-1.0f, 1.0f);
    Vector2 e3 = Vector2(1.0f, -1.0f);
    Vector2 e4 = Vector2(-1.0f, -1.0f);
    
    float d1 = mainSDF(p1, p2, p + eps * e1, shapeWidth, shapeHeight, shapeRadius, shapeRoundness, mergeRate, dpr, resolutionY, showShape1);
    float d2 = mainSDF(p1, p2, p + eps * e2, shapeWidth, shapeHeight, shapeRadius, shapeRoundness, mergeRate, dpr, resolutionY, showShape1);
    float d3 = mainSDF(p1, p2, p + eps * e3, shapeWidth, shapeHeight, shapeRadius, shapeRoundness, mergeRate, dpr, resolutionY, showShape1);
    float d4 = mainSDF(p1, p2, p + eps * e4, shapeWidth, shapeHeight, shapeRadius, shapeRoundness, mergeRate, dpr, resolutionY, showShape1);
    
    Vector2 grad = e1 * d1 + e2 * d2 + e3 * d3 + e4 * d4;
    return grad.normalized();
}

float computeRefractionEdgeFactor(float sdfValue, float thickness, float refFactor, float resolutionY) {
    float nmerged = -sdfValue * resolutionY;
    
    if (nmerged >= thickness) {
        return 0.0f;
    }
    
    float x_R_ratio = 1.0f - nmerged / thickness;
    float thetaI = (float)asin(pow(x_R_ratio, 2.0f));
    float sinThetaT = (1.0f / refFactor) * (float)sin(thetaI);
    
    if (sinThetaT > 1.0f || sinThetaT < -1.0f) {
        return 0.0f;
    }
    
    float thetaT = (float)asin(sinThetaT);
    float edgeFactor = -(float)tan(thetaT - thetaI);
    
    return godot::Math::max(edgeFactor, 0.0f);
}

float computeFresnelFactor(float sdfValue, float fresnelRange, float fresnelHardness, float resolutionY) {
    float factor = 1.0f + sdfValue * resolutionY / 1500.0f * (float)pow(500.0f / fresnelRange, 2.0f) + fresnelHardness;
    return godot::Math::clamp((float)pow(factor, 5.0f), 0.0f, 1.0f);
}

float computeGlareGeometryFactor(float sdfValue, float glareRange, float glareHardness, float resolutionY) {
    float factor = 1.0f + sdfValue * resolutionY / 1500.0f * (float)pow(500.0f / glareRange, 2.0f) + glareHardness;
    return godot::Math::clamp((float)pow(factor, 5.0f), 0.0f, 1.0f);
}

float computeGlareAngleFactor(const Vector2& normal, float glareAngle) {
    if (normal.length_squared() < 0.0001f) {
        return 0.0f;
    }
    
    Vector2 n = normal.normalized();
    float angle = (float)atan2(n.y, n.x);
    float adjustedAngle = (angle - (float)M_PI / 4.0f + glareAngle) * 2.0f;
    
    int glareFarside = 0;
    if ((adjustedAngle > (float)M_PI * (2.0f - 0.5f) && adjustedAngle < (float)M_PI * (4.0f - 0.5f)) || adjustedAngle < (float)M_PI * (0.0f - 0.5f)) {
        glareFarside = 1;
    }
    
    float angleFactor = (0.5f + (float)sin(adjustedAngle) * 0.5f) * (glareFarside == 1 ? 0.8f : 1.2f);
    return godot::Math::clamp(angleFactor, 0.0f, 1.0f);
}

}