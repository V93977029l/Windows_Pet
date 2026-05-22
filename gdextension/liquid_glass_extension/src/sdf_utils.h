#ifndef SDF_UTILS_H
#define SDF_UTILS_H

#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/core/math.hpp>

using namespace godot;

namespace LiquidGlassUtils {

float sdCircle(const Vector2& p, float r);

float superellipseCornerSDF(const Vector2& p, float r, float n);

float roundedRectSDF(const Vector2& p, const Vector2& center, float width, float height, float cornerRadius, float roundness);

float smin(float a, float b, float k);

float mainSDF(const Vector2& p1, const Vector2& p2, const Vector2& p, float shapeWidth, float shapeHeight, float shapeRadius, float shapeRoundness, float mergeRate, float dpr, float resolutionY, int showShape1);

Vector2 getNormal(const Vector2& p1, const Vector2& p2, const Vector2& p, float shapeWidth, float shapeHeight, float shapeRadius, float shapeRoundness, float mergeRate, float dpr, float resolutionY, int showShape1);

float computeRefractionEdgeFactor(float sdfValue, float thickness, float refFactor, float resolutionY);

float computeFresnelFactor(float sdfValue, float fresnelRange, float fresnelHardness, float resolutionY);

float computeGlareGeometryFactor(float sdfValue, float glareRange, float glareHardness, float resolutionY);

float computeGlareAngleFactor(const Vector2& normal, float glareAngle);

}

#endif