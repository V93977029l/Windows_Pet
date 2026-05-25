/*
 * ============================================================================
 * LiquidGlass 类实现 - 液态玻璃效果资源容器
 * ============================================================================
 *
 * 本文件包含 LiquidGlass 类的完整实现：
 * - _bind_methods()：将所有 C++ 方法和属性注册到 Godot 的反射系统
 * - getter/setter：简单的成员变量读写操作
 * - 计算方法：委托给 LiquidGlassUtils 命名空间中的 SDF 工具函数
 *
 * 架构设计：
 *   LiquidGlass (Resource 容器) → LiquidGlassUtils (SDF 计算引擎)
 *   这种分离使得 SDF 函数可以被其他模块复用，同时保持 Resource 类的简洁。
 */

#include "liquid_glass.h"
#include "sdf_utils.h"

using namespace godot;

/*
 * ============================================================================
 * _bind_methods() - Godot 方法/属性绑定
 * ============================================================================
 *
 * 这是 Godot GDExtension 最关键的注册函数。所有在此注册的方法和属性
 * 才能在 GDScript 中被调用，或在编辑器的 Inspector 面板中显示。
 *
 * 绑定分为两类：
 * 1. bind_method()：绑定可调用方法（GDScript 中的 func）
 * 2. ADD_PROPERTY()：绑定可编辑属性（Inspector 面板中的属性）
 *
 * 属性面板的编辑范围通过 PROPERTY_HINT_RANGE 指定：
 *   格式：PROPERTY_HINT_RANGE, "最小值,最大值,步长"
 *   例如 "1,80,0.01" 表示范围 1~80，滑块步长 0.01
 */
void LiquidGlass::_bind_methods() {
    // =========================================================================
    // 折射参数的方法绑定
    // =========================================================================
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
    
    // =========================================================================
    // 眩光参数的方法绑定
    // =========================================================================
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
    
    // =========================================================================
    // 模糊参数的方法绑定
    // =========================================================================
    ClassDB::bind_method(D_METHOD("set_blur_radius", "value"), &LiquidGlass::set_blur_radius);
    ClassDB::bind_method(D_METHOD("get_blur_radius"), &LiquidGlass::get_blur_radius);
    
    ClassDB::bind_method(D_METHOD("set_blur_edge", "value"), &LiquidGlass::set_blur_edge);
    ClassDB::bind_method(D_METHOD("get_blur_edge"), &LiquidGlass::get_blur_edge);
    
    // =========================================================================
    // 着色参数的方法绑定
    // =========================================================================
    ClassDB::bind_method(D_METHOD("set_tint", "value"), &LiquidGlass::set_tint);
    ClassDB::bind_method(D_METHOD("get_tint"), &LiquidGlass::get_tint);
    
    // =========================================================================
    // 形状参数的方法绑定
    // =========================================================================
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
    
    // =========================================================================
    // 计算方法的方法绑定
    // 这些是运行时可调用的计算方法，不是属性
    // =========================================================================
    
    /*
     * compute_normal() 绑定 - 计算 SDF 表面法线
     *   参数: p1(形状1位置), p2(形状2位置), p(查询点), dpr(设备像素比), resolutionY(分辨率)
     *   返回值: Vector2 法线向量
     */
    ClassDB::bind_method(D_METHOD("compute_normal", "p1", "p2", "p", "dpr", "resolutionY"), &LiquidGlass::compute_normal);
    
    /*
     * compute_refraction_edge_factor() 绑定 - 计算折射边缘偏移
     *   参数: sdfValue(SDF值), resolutionY(分辨率)
     *   返回值: float 折射偏移量
     */
    ClassDB::bind_method(D_METHOD("compute_refraction_edge_factor", "sdfValue", "resolutionY"), &LiquidGlass::compute_refraction_edge_factor);
    
    /*
     * compute_fresnel_factor() 绑定 - 计算菲涅尔因子
     *   参数: sdfValue(SDF值), resolutionY(分辨率)
     *   返回值: float 菲涅尔因子 (0~1)
     */
    ClassDB::bind_method(D_METHOD("compute_fresnel_factor", "sdfValue", "resolutionY"), &LiquidGlass::compute_fresnel_factor);
    
    /*
     * compute_glare_geometry_factor() 绑定 - 计算几何眩光因子
     *   参数: sdfValue(SDF值), resolutionY(分辨率)
     *   返回值: float 几何眩光因子 (0~1)
     */
    ClassDB::bind_method(D_METHOD("compute_glare_geometry_factor", "sdfValue", "resolutionY"), &LiquidGlass::compute_glare_geometry_factor);
    
    /*
     * compute_glare_angle_factor() 绑定 - 计算角度眩光因子
     *   参数: normal(表面法线向量)
     *   返回值: float 角度眩光因子 (0~1)
     */
    ClassDB::bind_method(D_METHOD("compute_glare_angle_factor", "normal"), &LiquidGlass::compute_glare_angle_factor);
    
    /*
     * compute_sdf() 绑定 - 计算主 SDF 值
     *   参数: p1, p2(形状位置), p(查询点), dpr(像素比), resolutionY(分辨率)
     *   返回值: float SDF 值
     */
    ClassDB::bind_method(D_METHOD("compute_sdf", "p1", "p2", "p", "dpr", "resolutionY"), &LiquidGlass::compute_sdf);
    
    // =========================================================================
    // 属性面板注册 (ADD_PROPERTY)
    // 使属性在 Godot 编辑器的 Inspector 中可编辑
    // PropertyInfo 参数：类型, 名称, 提示类型, 提示字符串
    // =========================================================================
    
    /*
     * ref_thickness 属性 - 面板范围 1~80，步长 0.01
     * 编辑器显示为带滑块的浮点数输入框
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ref_thickness", PROPERTY_HINT_RANGE, "1,80,0.01"), "set_ref_thickness", "get_ref_thickness");
    
    /*
     * ref_factor 属性 - 折射率，面板范围 1~4
     * 对应常见透明介质折射率范围
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ref_factor", PROPERTY_HINT_RANGE, "1,4,0.01"), "set_ref_factor", "get_ref_factor");
    
    /*
     * ref_dispersion 属性 - 色散强度，面板范围 0~50
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ref_dispersion", PROPERTY_HINT_RANGE, "0,50,0.01"), "set_ref_dispersion", "get_ref_dispersion");
    
    /*
     * ref_fresnel_range 属性 - 菲涅尔衰减范围，面板范围 0~100
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ref_fresnel_range", PROPERTY_HINT_RANGE, "0,100,0.01"), "set_ref_fresnel_range", "get_ref_fresnel_range");
    
    /*
     * ref_fresnel_hardness 属性 - 菲涅尔硬度，面板范围 0~1
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ref_fresnel_hardness", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_ref_fresnel_hardness", "get_ref_fresnel_hardness");
    
    /*
     * ref_fresnel_factor 属性 - 菲涅尔强度，面板范围 0~1
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ref_fresnel_factor", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_ref_fresnel_factor", "get_ref_fresnel_factor");
    
    /*
     * glare_range 属性 - 眩光范围，面板范围 0~100
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "glare_range", PROPERTY_HINT_RANGE, "0,100,0.01"), "set_glare_range", "get_glare_range");
    
    /*
     * glare_hardness 属性 - 眩光硬度，面板范围 0~1
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "glare_hardness", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_glare_hardness", "get_glare_hardness");
    
    /*
     * glare_convergence 属性 - 眩光汇聚度，面板范围 0~1
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "glare_convergence", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_glare_convergence", "get_glare_convergence");
    
    /*
     * glare_opposite_factor 属性 - 背面眩光因子，面板范围 0~1
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "glare_opposite_factor", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_glare_opposite_factor", "get_glare_opposite_factor");
    
    /*
     * glare_factor 属性 - 眩光全局强度，面板范围 0~1.2
     * 允许超过 1.0 支持 HDR 超亮效果
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "glare_factor", PROPERTY_HINT_RANGE, "0,1.2,0.01"), "set_glare_factor", "get_glare_factor");
    
    /*
     * glare_angle 属性 - 眩光主角度，面板范围 -π~π（弧度）
     * 对应 -180° ~ 180°，0° = 右侧光源
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "glare_angle", PROPERTY_HINT_RANGE, "-3.14159,3.14159,0.01"), "set_glare_angle", "get_glare_angle");
    
    /*
     * blur_radius 属性 - 模糊半径，面板范围 1~200，整数步长
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "blur_radius", PROPERTY_HINT_RANGE, "1,200,1"), "set_blur_radius", "get_blur_radius");
    
    /*
     * blur_edge 属性 - 是否启用边缘模糊，布尔类型复选框
     */
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "blur_edge"), "set_blur_edge", "get_blur_edge");
    
    /*
     * tint 属性 - 玻璃色调，颜色拾取器
     */
    ADD_PROPERTY(PropertyInfo(Variant::COLOR, "tint"), "set_tint", "get_tint");
    
    /*
     * shape_width 属性 - 形状宽度，面板范围 20~800
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shape_width", PROPERTY_HINT_RANGE, "20,800,1"), "set_shape_width", "get_shape_width");
    
    /*
     * shape_height 属性 - 形状高度，面板范围 20~800
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shape_height", PROPERTY_HINT_RANGE, "20,800,1"), "set_shape_height", "get_shape_height");
    
    /*
     * shape_radius 属性 - 圆角半径，面板范围 1~100
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shape_radius", PROPERTY_HINT_RANGE, "1,100,0.1"), "set_shape_radius", "get_shape_radius");
    
    /*
     * shape_roundness 属性 - 角形状指数（超椭圆 n 值），面板范围 2~7
     * n=2 标准椭圆，n=5 默认过渡，n=7 接近矩形
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shape_roundness", PROPERTY_HINT_RANGE, "2,7,0.01"), "set_shape_roundness", "get_shape_roundness");
    
    /*
     * merge_rate 属性 - 形状融合率，面板范围 0~0.3
     * 控制 smin 平滑最小值融合的过渡宽度
     */
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "merge_rate", PROPERTY_HINT_RANGE, "0,0.3,0.01"), "set_merge_rate", "get_merge_rate");
    
    /*
     * show_shape1 属性 - 是否显示圆形形状，布尔复选框
     */
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "show_shape1"), "set_show_shape1", "get_show_shape1");
}

/*
 * 构造函数 - 使用成员初始化列表中的默认值
 * 所有默认值已在头文件中内联定义，此处无需额外操作
 */
LiquidGlass::LiquidGlass() {
}

/*
 * 析构函数 - Resource 类析构由 Godot 内存管理负责
 * 无手动分配的资源需要释放
 */
LiquidGlass::~LiquidGlass() {
}

// =========================================================================
// 折射参数的 getter/setter 实现
// 每个属性都是一对简单的成员变量读写操作
// =========================================================================

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

// =========================================================================
// 眩光参数的 getter/setter 实现
// =========================================================================

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

// =========================================================================
// 模糊参数的 getter/setter 实现
// =========================================================================

void LiquidGlass::set_blur_radius(float value) { blurRadius = value; }
float LiquidGlass::get_blur_radius() const { return blurRadius; }

void LiquidGlass::set_blur_edge(bool value) { blurEdge = value; }
bool LiquidGlass::get_blur_edge() const { return blurEdge; }

// =========================================================================
// 着色参数的 getter/setter 实现
// =========================================================================

void LiquidGlass::set_tint(const Color& value) { tint = value; }
Color LiquidGlass::get_tint() const { return tint; }

// =========================================================================
// 形状参数的 getter/setter 实现
// =========================================================================

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

// =========================================================================
// 计算方法实现 - 委托给 LiquidGlassUtils 命名空间
// 这些方法的调用链如下：
//
// LiquidGlass::compute_normal()           → LiquidGlassUtils::getNormal()           → mainSDF() × 4次
// LiquidGlass::compute_sdf()              → LiquidGlassUtils::mainSDF()              → sdCircle() + roundedRectSDF() + smin()
// LiquidGlass::compute_refraction_edge()  → LiquidGlassUtils::computeRefractionEdgeFactor()
// LiquidGlass::compute_fresnel()          → LiquidGlassUtils::computeFresnelFactor()
// LiquidGlass::compute_glare_geometry()   → LiquidGlassUtils::computeGlareGeometryFactor()
// LiquidGlass::compute_glare_angle()      → LiquidGlassUtils::computeGlareAngleFactor()
// =========================================================================

/*
 * compute_normal() - 计算 SDF 表面法线向量
 *   委托给 LiquidGlassUtils::getNormal()
 *   将 showShape1 布尔值转换为整型（0/1）以适配底层接口
 *   传入当前存储的形状参数（宽度、高度、半径、圆度、融合率）
 *
 *   getNormal 内部使用四方向偏导数法（tetrahedron 方法）：
 *   在四个对角方向分别采样 SDF 值，然后加权组合得到梯度，
 *   最后归一化得到法线向量。
 */
Vector2 LiquidGlass::compute_normal(const Vector2& p1, const Vector2& p2, const Vector2& p, float dpr, float resolutionY) const {
    return LiquidGlassUtils::getNormal(p1, p2, p, shapeWidth, shapeHeight, shapeRadius, shapeRoundness, mergeRate, dpr, resolutionY, showShape1 ? 1 : 0);
}

/*
 * compute_refraction_edge_factor() - 计算折射边缘偏移因子
 *   委托给 LiquidGlassUtils::computeRefractionEdgeFactor()
 *   传入折射相关的物理参数：厚度(refThickness)、折射率(refFactor)
 *
 *   内部算法基于斯涅尔定律：
 *   1. 将 SDF 值转换为归一化距离 nmerged
 *   2. 计算光线在介质内部的入射角
 *   3. 使用折射率计算折射角
 *   4. 计算折射偏移的切向分量
 */
float LiquidGlass::compute_refraction_edge_factor(float sdfValue, float resolutionY) const {
    return LiquidGlassUtils::computeRefractionEdgeFactor(sdfValue, refThickness, refFactor, resolutionY);
}

/*
 * compute_fresnel_factor() - 计算菲涅尔反射因子
 *   委托给 LiquidGlassUtils::computeFresnelFactor()
 *   传入菲涅尔相关参数：范围(refFresnelRange)、硬度(refFresnelHardness)
 *
 *   内部算法：
 *   根据 SDF 值和菲涅尔参数计算一个指数因子，经过 5 次幂运算后
 *   映射到 [0,1] 范围，模拟掠射角反射率增大的物理现象。
 */
float LiquidGlass::compute_fresnel_factor(float sdfValue, float resolutionY) const {
    return LiquidGlassUtils::computeFresnelFactor(sdfValue, refFresnelRange, refFresnelHardness, resolutionY);
}

/*
 * compute_glare_geometry_factor() - 计算几何眩光因子
 *   委托给 LiquidGlassUtils::computeGlareGeometryFactor()
 *   传入眩光几何参数：范围(glareRange)、硬度(glareHardness)
 *
 *   算法与菲涅尔因子相同，但使用独立的参数组，
 *   使得眩光效果可以独立于菲涅尔效果进行调整。
 */
float LiquidGlass::compute_glare_geometry_factor(float sdfValue, float resolutionY) const {
    return LiquidGlassUtils::computeGlareGeometryFactor(sdfValue, glareRange, glareHardness, resolutionY);
}

/*
 * compute_glare_angle_factor() - 计算角度眩光因子
 *   委托给 LiquidGlassUtils::computeGlareAngleFactor()
 *   传入眩光主角度(glareAngle)
 *
 *   内部算法：
 *   根据法线方向与设定光源方向的夹角，使用正弦函数映射到 [0,1]，
 *   同时区分正面和背面区域给予不同的强度加权。
 */
float LiquidGlass::compute_glare_angle_factor(const Vector2& normal) const {
    return LiquidGlassUtils::computeGlareAngleFactor(normal, glareAngle);
}

/*
 * compute_sdf() - 计算合并后的主 SDF 值
 *   委托给 LiquidGlassUtils::mainSDF()
 *   传入所有形状参数和当前的显示设置
 *
 *   调用链：mainSDF() 内部依次调用：
 *   1. sdCircle() - 计算圆形形状的 SDF（如果 showShape1 == true）
 *   2. roundedRectSDF() - 计算圆角矩形的 SDF
 *   3. smin() - 使用平滑最小值函数将两个 SDF 融合
 *
 *   返回值：负值 = 像素在玻璃内部，正值 = 像素在玻璃外部
 */
float LiquidGlass::compute_sdf(const Vector2& p1, const Vector2& p2, const Vector2& p, float dpr, float resolutionY) const {
    return LiquidGlassUtils::mainSDF(p1, p2, p, shapeWidth, shapeHeight, shapeRadius, shapeRoundness, mergeRate, dpr, resolutionY, showShape1 ? 1 : 0);
}
