#ifndef LIQUID_GLASS_H
#define LIQUID_GLASS_H

/*
 * ============================================================================
 * LiquidGlass 类 - 液态玻璃效果资源容器
 * ============================================================================
 *
 * 【项目架构角色】
 *   本类是"液态玻璃"视觉效果的参数配置中心。它继承自 Godot 的 Resource 类，
 *   因此可以在编辑器中作为 .tres 文件保存/加载，支持 Inspector 面板可视化编辑。
 *   该类本身不执行渲染，而是作为数据容器，由着色器（Shader）或 GDScript 在
 *   运行时读取其属性值来计算最终的屏幕空间折射、菲涅尔和眩光效果。
 *
 * 【设计目的】
 *   将所有与液态玻璃外观相关的物理参数集中管理，包括：
 *   - 折射参数：模拟光线穿过玻璃介质时的弯曲和色散
 *   - 眩光参数：模拟光源在玻璃表面产生的高光反射
 *   - 模糊参数：控制玻璃边缘的柔化程度
 *   - 着色参数：玻璃的整体色调
 *   - 形状参数：定义玻璃轮廓的几何属性
 *
 * 【SDF 说明】
 *   本类使用了 SDF（Signed Distance Function，有符号距离函数）技术来描述
 *   玻璃的形状轮廓。compute_normal()、compute_sdf() 等方法委托给
 *   LiquidGlassUtils 命名空间中的函数执行实际计算。
 */

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/color.hpp>

using namespace godot;

class LiquidGlass : public Resource {
    GDCLASS(LiquidGlass, Resource)
    
private:
    // =========================================================================
    // 折射参数组 (Refraction Parameters)
    // 模拟光线从一种介质进入另一种介质时的弯曲行为
    // 参考斯涅尔定律 (Snell's Law): n1 * sin(θ1) = n2 * sin(θ2)
    // =========================================================================

    /*
     * refThickness - 玻璃厚度（单位：像素，默认 20.0）
     *   物理含义：模拟的玻璃介质的厚度。厚度越大，光线在介质内部传播的
     *   路径越长，折射偏移越明显。
     *   视觉效果：增大此值 → 玻璃边缘的折射偏移量增大，物体看起来更"厚"；
     *            减小此值 → 折射效果减弱，玻璃看起来更薄。
     *   默认值 20.0 对应中等厚度，产生适中的折射效果。
     */
    float refThickness = 20.0f;

    /*
     * refFactor - 折射率（无量纲，默认 1.4）
     *   物理含义：玻璃介质相对于空气的折射率（IOR, Index of Refraction）。
     *   1.0 = 无折射（光线不弯曲），1.33 = 水的折射率，1.4~1.5 = 普通玻璃，
     *   1.6~1.7 = 高折射率玻璃（如燧石玻璃），2.4 = 钻石。
     *   视觉效果：折射率越大，背后物体的偏移/扭曲越严重。
     *   默认值 1.4 模拟普通玻璃的折射特性。
     */
    float refFactor = 1.4f;

    /*
     * refDispersion - 色散强度（默认 7.0）
     *   物理含义：不同波长（颜色）的光在介质中折射率的差异程度。
     *   现实中的三棱镜分光就是色散效应。
     *   视觉效果：增大此值 → RGB 三个通道的折射偏移差异增大，产生彩色
     *   边缘（色差/色散效果）；设为 0 则无色散。
     *   默认值 7.0 产生明显但不夸张的彩虹色边缘。
     */
    float refDispersion = 7.0f;

    /*
     * refFresnelRange - 菲涅尔衰减范围（单位：像素，默认 30.0）
     *   物理含义：控制菲涅尔效应从玻璃中心到边缘的渐变过渡距离。
     *   菲涅尔效应：视线与表面法线的夹角越大，反射率越高。
     *   此值决定 SDF 值到菲涅尔因子的映射曲线的"宽度"。
     *   视觉效果：值越小 → 菲涅尔效果集中在边缘，中心区域基本无效果；
     *            值越大 → 菲涅尔效果向中心扩展。
     */
    float refFresnelRange = 30.0f;

    /*
     * refFresnelHardness - 菲涅尔硬度（范围 0~1，默认 0.2）
     *   物理含义：菲涅尔过渡的锐利程度。控制边缘反射从无到有的突变程度。
     *   视觉效果：0.0 = 极柔和渐变，1.0 = 极锐利边缘。
     *   默认值 0.2 产生柔和自然的菲涅尔过渡。
     */
    float refFresnelHardness = 0.2f;

    /*
     * refFresnelFactor - 菲涅尔强度因子（范围 0~1，默认 0.2）
     *   物理含义：菲涅尔反射效果的全局强度倍率。
     *   视觉效果：0.0 = 无菲涅尔效果，1.0 = 最大菲涅尔反射强度。
     *   与折射效果结合使用：菲涅尔越强，边缘看起来越像镜面反射。
     *   默认值 0.2 产生微妙的边缘高光。
     */
    float refFresnelFactor = 0.2f;
    
    // =========================================================================
    // 眩光参数组 (Glare Parameters)
    // 模拟光源在曲面玻璃上产生的定向高光
    // =========================================================================

    /*
     * glareRange - 眩光衰减范围（单位：像素，默认 30.0）
     *   物理含义：控制眩光效果从玻璃中心到边缘的渐变过渡距离。
     *   与菲涅尔范围的原理类似，但独立控制眩光效果。
     *   视觉效果：值越小 → 眩光集中在边缘；值越大 → 眩光扩散到中心。
     */
    float glareRange = 30.0f;

    /*
     * glareHardness - 眩光硬度（范围 0~1，默认 0.2）
     *   物理含义：眩光过渡的锐利程度。
     *   视觉效果：0.0 = 柔和渐变，1.0 = 锐利边缘眩光。
     *   默认值 0.2 产生柔和的高光过渡。
     */
    float glareHardness = 0.2f;

    /*
     * glareConvergence - 眩光汇聚度（范围 0~1，默认 0.5）
     *   物理含义：控制眩光在法线方向上的集中程度。
     *   类似于聚光灯的"光束集中度"——值越高，眩光越集中在特定角度。
     *   视觉效果：0.0 = 漫反射式均匀眩光，1.0 = 镜面反射式集中眩光。
     */
    float glareConvergence = 0.5f;

    /*
     * glareOppositeFactor - 背面眩光因子（范围 0~1，默认 0.8）
     *   物理含义：玻璃背面区域的眩光相对强度。
     *   当光源从玻璃背面方向照射时，会产生次级的背面眩光。
     *   视觉效果：0.0 = 仅正面有眩光；1.0 = 正面和背面眩光强度相同。
     *   默认值 0.8 使背面眩光略弱于正面，产生自然的层次感。
     */
    float glareOppositeFactor = 0.8f;

    /*
     * glareFactor - 眩光全局强度（范围 0~1.2，默认 0.9）
     *   物理含义：眩光效果的全局倍率，可超过 1.0 以获得超亮效果。
     *   视觉效果：0.0 = 无眩光；0.9 = 默认明显的眩光；1.2 = 超强眩光。
     */
    float glareFactor = 0.9f;

    /*
     * glareAngle - 眩光主角度（弧度，默认 -π/4 = -45°）
     *   物理含义：眩光高光的"主方向"角度。模拟光源相对于玻璃的方向。
     *   0° = 右侧光源，π/2 = 下方光源，-π/4 = 右上方光源（默认）。
     *   视觉效果：改变此值会旋转眩光高光在玻璃上的位置。
     *   默认值 -45° 对应常见的"左上光源"设置。
     */
    float glareAngle = -Math_PI / 4.0f;
    
    // =========================================================================
    // 模糊参数组 (Blur Parameters)
    // =========================================================================

    /*
     * blurRadius - 模糊半径（单位：像素，默认 1.0）
     *   物理含义：高斯模糊的核半径，控制玻璃边缘的柔化程度。
     *   视觉效果：1.0 = 基本无模糊（锐利边缘）；较大的值产生柔和的
     *   磨砂玻璃边缘效果。
     */
    float blurRadius = 1.0f;

    /*
     * blurEdge - 是否启用边缘模糊（默认 true）
     *   物理含义：控制是否对 SDF 计算出的玻璃边缘进行模糊处理。
     *   视觉效果：true = 边缘被高斯模糊柔化（磨砂玻璃质感）；
     *            false = 边缘锐利清晰（透明玻璃质感）。
     */
    bool blurEdge = true;
    
    // =========================================================================
    // 着色参数 (Tint Parameter)
    // =========================================================================

    /*
     * tint - 玻璃色调 (Color, 默认白色透明 rgba(1,1,1,0))
     *   物理含义：玻璃本身对光线的吸收/过滤颜色。
     *   默认值 (1,1,1,0) 表示完全无色透明。
     *   视觉效果：设置 alpha > 0 可为玻璃添加颜色覆盖，如浅蓝、浅绿等。
     *   RGB 通道控制色调，A 通道控制着色强度。
     */
    Color tint = Color(1.0f, 1.0f, 1.0f, 0.0f);
    
    // =========================================================================
    // 形状参数组 (Shape Parameters)
    // 定义玻璃外形的几何属性
    // =========================================================================

    /*
     * shapeWidth - 形状宽度（单位：像素，默认 200.0）
     *   物理含义：圆角矩形玻璃轮廓的宽度。
     *   视觉效果：决定玻璃元素的水平尺寸。
     */
    float shapeWidth = 200.0f;

    /*
     * shapeHeight - 形状高度（单位：像素，默认 200.0）
     *   物理含义：圆角矩形玻璃轮廓的高度。
     *   视觉效果：决定玻璃元素的垂直尺寸。
     */
    float shapeHeight = 200.0f;

    /*
     * shapeRadius - 圆角半径（单位：像素，默认 80.0）
     *   物理含义：圆角矩形四个角的圆弧半径。
     *   视觉效果：值越小 → 矩形角越尖锐；值越大 → 矩形角越圆润。
     *   当值 ≥ min(width,height)/2 时，形状变为完全圆角（胶囊形）。
     */
    float shapeRadius = 80.0f;

    /*
     * shapeRoundness - 角形状指数（范围 2~7，默认 5.0）
     *   物理含义：超椭圆指数的 n 值，控制角部的"方圆程度"。
     *   n=2 为标准椭圆角（圆润过渡），n→∞ 趋近于纯矩形。
     *   在 SDF 中通过 superellipseCornerSDF 函数实现。
     *   视觉效果：2.0 = 标准圆弧角；5.0 = 介于方圆之间的过渡；
     *            7.0 = 更接近矩形的硬角。
     */
    float shapeRoundness = 5.0f;

    /*
     * mergeRate - 形状融合率（范围 0~0.3，默认 0.05）
     *   物理含义：当存在两个形状时，使用 smin（平滑最小值）将它们融合在一起
     *   的过渡平滑度。值越大，两个形状之间的融合区域越宽。
     *   视觉效果：0.0 = 形状间硬切换（无融合）；0.05 = 微妙的融合过渡；
     *            0.3 = 明显的"液态"融合效果。
     */
    float mergeRate = 0.05f;

    /*
     * showShape1 - 是否显示形状1（圆形）（默认 true）
     *   物理含义：控制第一个 SDF 形状（圆形）是否参与渲染。
     *   当为 false 时，只显示圆角矩形形状。
     *   视觉效果：true = 圆形 + 矩形融合效果；false = 仅矩形。
     */
    bool showShape1 = true;
    
protected:
    /*
     * _bind_methods() - 绑定方法到 Godot
     *   将 C++ 方法暴露给 GDScript/编辑器，并定义属性面板的显示方式。
     *   详见 liquid_glass.cpp 中的实现。
     */
    static void _bind_methods();
    
public:
    LiquidGlass();
    ~LiquidGlass();
    
    // =========================================================================
    // 折射属性的 getter/setter
    // =========================================================================
    
    /*
     * ref_thickness 属性访问器
     *   物理范围：1~80 像素，步长 0.01
     *   过薄（<5）：折射几乎不可见
     *   过厚（>50）：折射失真严重，可能产生不自然的扭曲
     */
    void set_ref_thickness(float value);
    float get_ref_thickness() const;
    
    /*
     * ref_factor 属性访问器 - 折射率
     *   物理范围：1.0~4.0，步长 0.01
     *   1.0 = 空气（无折射），4.0 = 极高折射率（如锗）
     *   典型玻璃：1.4~1.7
     */
    void set_ref_factor(float value);
    float get_ref_factor() const;
    
    /*
     * ref_dispersion 属性访问器 - 色散强度
     *   范围：0~50，步长 0.01
     *   0 = 无色散，10~50 = 强烈彩虹色散
     */
    void set_ref_dispersion(float value);
    float get_ref_dispersion() const;
    
    /*
     * ref_fresnel_range 属性访问器 - 菲涅尔范围
     *   范围：0~100 像素，步长 0.01
     */
    void set_ref_fresnel_range(float value);
    float get_ref_fresnel_range() const;
    
    /*
     * ref_fresnel_hardness 属性访问器 - 菲涅尔硬度
     *   范围：0~1，步长 0.01
     */
    void set_ref_fresnel_hardness(float value);
    float get_ref_fresnel_hardness() const;
    
    /*
     * ref_fresnel_factor 属性访问器 - 菲涅尔强度
     *   范围：0~1，步长 0.01
     */
    void set_ref_fresnel_factor(float value);
    float get_ref_fresnel_factor() const;
    
    // =========================================================================
    // 眩光属性的 getter/setter
    // =========================================================================
    
    /*
     * glare_range 属性访问器 - 眩光范围
     *   范围：0~100 像素，步长 0.01
     */
    void set_glare_range(float value);
    float get_glare_range() const;
    
    /*
     * glare_hardness 属性访问器 - 眩光硬度
     *   范围：0~1，步长 0.01
     */
    void set_glare_hardness(float value);
    float get_glare_hardness() const;
    
    /*
     * glare_convergence 属性访问器 - 眩光汇聚度
     *   范围：0~1，步长 0.01
     */
    void set_glare_convergence(float value);
    float get_glare_convergence() const;
    
    /*
     * glare_opposite_factor 属性访问器 - 背面眩光因子
     *   范围：0~1，步长 0.01
     */
    void set_glare_opposite_factor(float value);
    float get_glare_opposite_factor() const;
    
    /*
     * glare_factor 属性访问器 - 眩光全局强度
     *   范围：0~1.2，步长 0.01
     *   允许超过 1.0 以产生超亮眩光（HDR 风格）
     */
    void set_glare_factor(float value);
    float get_glare_factor() const;
    
    /*
     * glare_angle 属性访问器 - 眩光主角度
     *   范围：-π ~ π（-180° ~ 180°），步长 0.01
     *   以弧度为单位，0° = 右侧光源
     */
    void set_glare_angle(float value);
    float get_glare_angle() const;
    
    // =========================================================================
    // 模糊属性的 getter/setter
    // =========================================================================
    
    /*
     * blur_radius 属性访问器 - 模糊半径
     *   范围：1~200 像素，步长 1
     *   大值（>50）产生强烈的磨砂玻璃效果，但性能开销大
     */
    void set_blur_radius(float value);
    float get_blur_radius() const;
    
    /*
     * blur_edge 属性访问器 - 是否启用边缘模糊
     */
    void set_blur_edge(bool value);
    bool get_blur_edge() const;
    
    // =========================================================================
    // 着色属性的 getter/setter
    // =========================================================================
    
    /*
     * tint 属性访问器 - 玻璃色调
     *   RGB + Alpha，支持颜色拾取器
     */
    void set_tint(const Color& value);
    Color get_tint() const;
    
    // =========================================================================
    // 形状属性的 getter/setter
    // =========================================================================
    
    /*
     * shape_width 属性访问器 - 形状宽度
     *   范围：20~800 像素，步长 1
     */
    void set_shape_width(float value);
    float get_shape_width() const;
    
    /*
     * shape_height 属性访问器 - 形状高度
     *   范围：20~800 像素，步长 1
     */
    void set_shape_height(float value);
    float get_shape_height() const;
    
    /*
     * shape_radius 属性访问器 - 圆角半径
     *   范围：1~100 像素，步长 0.1
     */
    void set_shape_radius(float value);
    float get_shape_radius() const;
    
    /*
     * shape_roundness 属性访问器 - 角形状指数（超椭圆 n 值）
     *   范围：2~7，步长 0.01
     */
    void set_shape_roundness(float value);
    float get_shape_roundness() const;
    
    /*
     * merge_rate 属性访问器 - 形状融合率
     *   范围：0~0.3，步长 0.01
     */
    void set_merge_rate(float value);
    float get_merge_rate() const;
    
    /*
     * show_shape1 属性访问器 - 是否显示形状1（圆形）
     */
    void set_show_shape1(bool value);
    bool get_show_shape1() const;
    
    // =========================================================================
    // 计算方法 - 委托给 LiquidGlassUtils 命名空间
    // 这些方法供着色器或 GDScript 在运行时调用
    // =========================================================================
    
    /*
     * compute_normal() - 计算 SDF 表面在给定点的法线向量
     *   p1: 形状1（圆形）的中心位置（屏幕空间像素坐标）
     *   p2: 形状2（圆角矩形）的中心位置
     *   p:  查询点的位置
     *   dpr: 设备像素比（Device Pixel Ratio），用于 HiDPI 屏幕适配
     *   resolutionY: 屏幕垂直分辨率
     *   返回值：单位法线向量（已归一化）
     *
     *   调用链：compute_normal() → LiquidGlassUtils::getNormal() → LiquidGlassUtils::mainSDF() × 4
     *   使用四方向偏导数（tetrahedron 方法）计算梯度，比中心差分法更精确。
     */
    Vector2 compute_normal(const Vector2& p1, const Vector2& p2, const Vector2& p, float dpr, float resolutionY) const;
    
    /*
     * compute_refraction_edge_factor() - 计算折射边缘偏移因子
     *   sdfValue: 当前像素的 SDF 值（负值=内部，正值=外部）
     *   resolutionY: 屏幕垂直分辨率
     *   返回值：折射偏移量（≥0），0 表示无折射
     *
     *   调用链：compute_refraction_edge_factor() → LiquidGlassUtils::computeRefractionEdgeFactor()
     *   内部使用斯涅尔定律计算光线穿过玻璃后的偏移量。
     */
    float compute_refraction_edge_factor(float sdfValue, float resolutionY) const;
    
    /*
     * compute_fresnel_factor() - 计算菲涅尔因子
     *   sdfValue: 当前像素的 SDF 值
     *   resolutionY: 屏幕垂直分辨率
     *   返回值：0~1 之间的菲涅尔强度因子
     *
     *   调用链：compute_fresnel_factor() → LiquidGlassUtils::computeFresnelFactor()
     *   SDF 值越接近 0（边缘），菲涅尔因子越接近 1。
     */
    float compute_fresnel_factor(float sdfValue, float resolutionY) const;
    
    /*
     * compute_glare_geometry_factor() - 计算几何眩光因子
     *   sdfValue: 当前像素的 SDF 值
     *   resolutionY: 屏幕垂直分辨率
     *   返回值：0~1 之间的几何眩光强度
     *
     *   调用链：compute_glare_geometry_factor() → LiquidGlassUtils::computeGlareGeometryFactor()
     *   与菲涅尔因子计算方式类似，但使用独立的参数组。
     */
    float compute_glare_geometry_factor(float sdfValue, float resolutionY) const;
    
    /*
     * compute_glare_angle_factor() - 计算角度眩光因子
     *   normal: SDF 表面的法线向量
     *   返回值：0~1 之间的角度眩光强度
     *
     *   调用链：compute_glare_angle_factor() → LiquidGlassUtils::computeGlareAngleFactor()
     *   根据法线方向与光源方向的夹角计算高光强度。
     */
    float compute_glare_angle_factor(const Vector2& normal) const;
    
    /*
     * compute_sdf() - 计算主 SDF 值
     *   p1, p2: 两个形状的中心位置
     *   p: 查询点位置
     *   dpr: 设备像素比
     *   resolutionY: 屏幕垂直分辨率
     *   返回值：合并后的 SDF 值
     *
     *   调用链：compute_sdf() → LiquidGlassUtils::mainSDF()
     *         → sdCircle() + roundedRectSDF() + smin()
     *   将两个形状的 SDF 通过平滑最小值（smin）合并。
     */
    float compute_sdf(const Vector2& p1, const Vector2& p2, const Vector2& p, float dpr, float resolutionY) const;
};

#endif
