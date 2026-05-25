/*
 * ============================================================================
 * SDF 工具函数实现 - 液态玻璃渲染的数学计算核心
 * ============================================================================
 *
 * 【实现概述】
 *   本文件包含 8 个 SDF 相关函数的算法级实现。这些函数与着色器中的
 *   sdf_utils.inc 文件一一对应，确保 CPU 端和 GPU 端的计算结果数学等价。
 *
 *   函数列表：
 *   1. sdCircle()               - 圆形 SDF
 *   2. superellipseCornerSDF()  - 超椭圆角 SDF
 *   3. roundedRectSDF()         - 圆角矩形 SDF
 *   4. smin()                   - 平滑最小值
 *   5. mainSDF()                - 主 SDF 合并函数
 *   6. getNormal()              - 法线向量计算
 *   7. computeRefractionEdgeFactor()  - 折射边缘偏移
 *   8. computeFresnelFactor()         - 菲涅尔因子
 *   9. computeGlareGeometryFactor()   - 几何眩光因子
 *  10. computeGlareAngleFactor()      - 角度眩光因子
 *
 * 【坐标系约定】
 *   所有 SDF 函数使用基于 resolutionY 归一化的坐标系统：
 *   - 输入位置除以 resolutionY 后映射到 [0, 1] 空间
 *   - 这使得 SDF 值与屏幕分辨率无关
 *   - DPR（Device Pixel Ratio）用于 HiDPI 适配
 */

#include "sdf_utils.h"
#include <cmath>

namespace LiquidGlassUtils {

/*
 * M_PI 定义 - 圆周率常量
 * 一些编译器/标准库可能不定义 M_PI，这里手动定义以保兼容
 * 值 3.14159265358979323846 提供了双精度级别的精度
 */
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// =========================================================================
// sdCircle() - 圆形有符号距离函数
// =========================================================================
/*
 * 算法：sdCircle(p, r) = ||p|| - r
 *
 * 这是最基础、最简单的 SDF 形式。
 *
 * 计算流程：
 *   1. p.length() 计算点 p 到原点的欧几里得距离
 *   2. 减去半径 r 得到有符号距离
 *   3. 结果：负值 = 点在圆内，0 = 在圆周上，正值 = 在圆外
 *
 * 示例：
 *   sdCircle(Vector2(0, 0), 5)  = 0 - 5 = -5  （圆心在圆内）
 *   sdCircle(Vector2(5, 0), 5)  = 5 - 5 = 0   （圆边界上）
 *   sdCircle(Vector2(10, 0), 5) = 10 - 5 = 5  （圆外）
 *
 * 与着色器对应：sdf_utils.inc 中的 sdCircle()
 */
float sdCircle(const Vector2& p, float r) {
    return p.length() - r;
}

// =========================================================================
// superellipseCornerSDF() - 超椭圆角有符号距离函数
// =========================================================================
/*
 * 算法：superellipseCornerSDF(p, r, n) = (|px|^n + |py|^n)^(1/n) - r
 *
 * 超椭圆（Superellipse）是 Lamé 曲线的一种，由方程描述：
 *   |x/a|^n + |y/b|^n = 1
 *
 * 当 a=b=r 时，n=2 为标准圆，n=4 为"squircle"（方圆），n→∞ 趋近正方形。
 *
 * 计算流程（逐行）：
 *   行 1：abs_p = p.abs()
 *     - 取坐标绝对值，因为超椭圆是对称的，只需处理第一象限
 *
 *   行 2：v = pow(pow(abs_p.x, n) + pow(abs_p.y, n), 1.0/n)
 *     - pow(abs_p.x, n)：x 坐标的 n 次幂
 *     - pow(abs_p.y, n)：y 坐标的 n 次幂
 *     - 两者相加得到超椭圆的"标准化距离"
 *     - pow(..., 1.0/n)：开 n 次根，还原到欧几里得尺度
 *
 *   行 3：return v - r
 *     - 减去半径得到有符号距离
 *
 * 性能分析：
 *   - pow() 是代价最高的运算（内部调用 exp/log）
 *   - 每次调用需要 3 次 pow()
 *   - roundedRectSDF 在角部区域才调用此函数，所以实际开销可控
 *
 * 与着色器对应：sdf_utils.inc 中的 superellipseCornerSDF()
 */
float superellipseCornerSDF(const Vector2& p, float r, float n) {
    Vector2 abs_p = p.abs();
    float v = pow(pow((float)abs_p.x, n) + pow((float)abs_p.y, n), 1.0f / n);
    return v - r;
}

// =========================================================================
// roundedRectSDF() - 圆角矩形有符号距离函数
// =========================================================================
/*
 * 算法：将一个矩形与超椭圆角结合，形成可调节圆角程度的矩形 SDF
 *
 * 计算流程（逐行）：
 *
 *   行 1：local_p = p - center
 *     - 将查询点转换到矩形的局部坐标系（矩形中心为原点）
 *
 *   行 2：cr = cornerRadius
 *     - 局部变量，圆角半径
 *
 *   行 3：d = local_p.abs() - Vector2(width/2, height/2)
 *     - 计算点相对于矩形各边的"超出量"
 *     - d.x > 0 表示点在矩形右边界之外
 *     - d.y > 0 表示点在矩形上边界之外
 *     - 负值表示点在对应边界的内部
 *
 *   行 4~8（角部区域判断）：
 *     条件：d.x > -cr && d.y > -cr
 *     - 当点距离两个边都足够近（距离小于圆角半径的负数）时，
 *       说明点在角部区域，需要使用超椭圆角计算
 *
 *     角部处理（行 5~7）：
 *     - cornerCenter = local_p.sign() * (Vector2(w,h)*0.5 - Vector2(cr,cr))
 *       计算角中心的坐标：sign() 确定角所在象限，
 *       (w/2 - cr, h/2 - cr) 是角中心相对于矩形中心的偏移
 *
 *     - cornerP = local_p - cornerCenter
 *       将点转换到角的局部坐标
 *
 *     - dist = superellipseCornerSDF(cornerP, cr, roundness)
 *       使用超椭圆角计算 SDF
 *
 *   行 9（标准矩形区域）：
 *     公式：dist = min(max(d.x, d.y), 0) + max(d, (0,0)).length()
 *     - min(max(d.x, d.y), 0)：内部距离（负值 = 在内部，0 = 在外部）
 *     - max(d, (0,0)).length()：外部距离（仅在 d > 0 时非零）
 *     - 两者相加得到完整的 SDF
 *
 * 与着色器对应：sdf_utils.inc 中的 roundedRectSDF()
 */
float roundedRectSDF(const Vector2& p, const Vector2& center, float width, float height, float cornerRadius, float roundness) {
    Vector2 local_p = p - center;
    float cr = cornerRadius;
    
    Vector2 d = local_p.abs() - Vector2(width, height) * 0.5f;
    
    float dist;
    
    if (d.x > -cr && d.y > -cr) {
        // === 角部区域：使用超椭圆角计算 ===
        Vector2 cornerCenter = local_p.sign() * (Vector2(width, height) * 0.5f - Vector2(cr, cr));
        Vector2 cornerP = local_p - cornerCenter;
        dist = superellipseCornerSDF(cornerP, cr, roundness);
    } else {
        // === 非角部区域：标准矩形 SDF 公式 ===
        dist = godot::Math::min(godot::Math::max(d.x, d.y), 0.0f) + godot::Math::max(d, Vector2(0.0f, 0.0f)).length();
    }
    
    return dist;
}

// =========================================================================
// smin() - 平滑最小值 (Smooth Minimum)
// =========================================================================
/*
 * 算法：Inigo Quilez 的多项式平滑最小值
 *   smin(a, b, k) = mix(a, b, h) - k * h * (1 - h)
 *   其中 h = clamp(0.5 + 0.5*(b-a)/k, 0.0, 1.0)
 *
 * 这是液态玻璃"液态融合"视觉的核心数学工具。
 *
 * 计算流程（逐行）：
 *
 *   行 1：h = clamp(0.5 + 0.5*(b-a)/k, 0, 1)
 *     - 0.5 + 0.5*(b-a)/k 将差值映射到以 0.5 为中心的插值区间
 *     - 除以 k 控制过渡宽度：k 越大过渡越平滑
 *     - clamp 到 [0,1] 确保插值因子合法
 *
 *   行 2：mix_val = b*(1-h) + a*h
 *     - 标准线性插值，等效于 lerp(b, a, h)
 *     - h=0 时取 b，h=1 时取 a
 *
 *   行 3：return mix_val - k*h*(1-h)
 *     - 减去惩罚项 k*h*(1-h) 确保函数平滑
 *     - h*(1-h) 在 h=0.5 时最大（=0.25），在 h=0 或 1 时最小（=0）
 *     - 乘以 k 后，惩罚项使过渡区域的 SDF 值略小于真正的 min
 *     - 这正是"平滑"效果的本质：在过渡区域产生比 min 更低的 SDF 值
 *
 * 视觉效果：
 *   k=0.0：硬切换（等价于 min）
 *   k=0.05：微妙融合（默认值）
 *   k=0.3：显著融合（明显液态效果）
 *
 * 与着色器对应：sdf_utils.inc 中的 smin()
 */
float smin(float a, float b, float k) {
    float h = godot::Math::clamp(0.5f + 0.5f * (b - a) / k, 0.0f, 1.0f);
    float mix_val = b * (1.0f - h) + a * h;
    return mix_val - k * h * (1.0f - h);
}

// =========================================================================
// mainSDF() - 主 SDF 合并函数
// =========================================================================
/*
 * 算法：将圆形和圆角矩形通过 smin 合并为统一的玻璃轮廓 SDF
 *
 * 计算流程（逐行）：
 *
 *   行 1~2：坐标归一化
 *     p1n = p1 + p/resolutionY
 *     p2n = p2 + p/resolutionY
 *     - 将像素坐标 p 除以 resolutionY 映射到 [0,1] 空间
 *     - 与 p1/p2 的中心偏移相加，得到归一化的查询位置
 *
 *   行 3：圆形 SDF
 *     d1 = (showShape1 == 1) ? sdCircle(p1n, 100*dpr/resolutionY) : 1.0
 *     - 如果显示圆形：计算半径为 100*dpr/resolutionY 的圆形 SDF
 *     - 100 是基准半径（像素），乘以 dpr 适配 HiDPI
 *     - 除以 resolutionY 完成归一化
 *     - 如果不显示：返回 1.0（完全在形状外部）
 *
 *   行 4~9：圆角矩形 SDF
 *     d2 = roundedRectSDF(p2n, Vector2(0,0), w/resY, h/resY, r/resY, roundness)
 *     - 矩形中心在原点 (0, 0)
 *     - 所有尺寸参数都除以 resolutionY 完成归一化
 *
 *   行 10：平滑融合
 *     return smin(d1, d2, mergeRate)
 *     - 使用 mergeRate 控制的平滑最小值合并两个形状
 *     - mergeRate 越大，融合过渡越平滑
 *
 * 与着色器对应：sdf_utils.inc 中的 mainSDF()
 */
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

// =========================================================================
// getNormal() - SDF 表面法线向量计算（tetrahedron 方法）
// =========================================================================
/*
 * 算法：使用四方向偏导数（tetrahedron 方法）计算 SDF 的梯度，
 *       然后归一化得到法线向量。
 *
 * 数学原理：法线 = normalize(∇f) = (∂f/∂x, ∂f/∂y) / |∇f|
 *
 * 四方向法（tetrahedron）的优势：
 *   - 比传统的中心差分法（只在 x 和 y 方向采样）旋转对称性更好
 *   - 减少了轴向偏差（anisotropy）
 *   - 计算成本：需要 4 次 SDF 采样 vs 中心差分的 4 次（如果算上交叉项则相同）
 *
 * 计算流程（逐行）：
 *
 *   行 1：eps = 0.7071 * 0.0005 ≈ 0.000354
 *     - 数值微分的步长
 *     - 0.0005 是基础步长，足够小以保证精度，足够大以避免浮点误差
 *     - 0.7071 = 1/√2，将对角方向长度转换为与轴对齐的等效长度
 *       （对角线 (1,1) 的长度是 √2，所以投影到 x 和 y 轴各是 1/√2）
 *
 *   行 2~5：定义四个对角偏导方向
 *     e1 = ( 1,  1)  东南（右下）
 *     e2 = (-1,  1)  西南（左下）
 *     e3 = ( 1, -1)  东北（右上）
 *     e4 = (-1, -1)  西北（左上）
 *
 *   行 6~9：在四个方向采样 SDF
 *     d1 = mainSDF(p + eps*e1)  东南方向偏移的 SDF
 *     d2 = mainSDF(p + eps*e2)  西南方向偏移的 SDF
 *     d3 = mainSDF(p + eps*e3)  东北方向偏移的 SDF
 *     d4 = mainSDF(p + eps*e4)  西北方向偏移的 SDF
 *
 *   行 10：grad = e1*d1 + e2*d2 + e3*d3 + e4*d4
 *     - 加权求和得到梯度向量
 *     - 每个方向向量乘以该方向的 SDF 采样值
 *     - 组合后得到 (∂f/∂x, ∂f/∂y) 的近似值
 *
 *   行 11：return grad.normalized()
 *     - 归一化梯度得到单位法线向量
 *     - 法线方向指向 SDF 值增大的方向（即向外）
 *
 * 示例理解：
 *   如果 SDF 在东南方向值大（远离表面）、西北方向值小（接近表面），
 *   则法线指向东南，表示表面在该点的向外方向。
 *
 * 与着色器对应：sdf_utils.inc 中的 getNormal()
 */
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

// =========================================================================
// computeRefractionEdgeFactor() - 折射边缘偏移因子
// =========================================================================
/*
 * 算法：基于斯涅尔定律（Snell's Law）模拟光线穿过玻璃介质时的弯曲
 *
 * 斯涅尔定律：n1 * sin(θ1) = n2 * sin(θ2)
 * 其中 n1=1.0（空气），n2=refFactor（玻璃折射率）
 *
 * 计算流程（逐行）：
 *
 *   行 1：nmerged = -sdfValue * resolutionY
 *     - sdfValue 是归一化后的 SDF 值（负数=内部）
 *     - 取反后乘以 resolutionY 恢复为像素空间距离
 *     - nmerged 表示当前像素到玻璃表面的像素距离（正值=在内部）
 *
 *   行 2：if (nmerged >= thickness) return 0.0
 *     - 如果像素到表面的距离已经超过玻璃厚度
 *     - 说明光线已经"穿透"了玻璃，无需折射计算
 *     - 这实际上也是一层性能优化：超出厚度的像素跳过计算
 *
 *   行 3：x_R_ratio = 1 - nmerged / thickness
 *     - 计算像素在玻璃内部的位置比例
 *     - 0.0 = 正好在玻璃表面
 *     - 1.0 = 在玻璃中心（距离表面 = thickness）
 *     - 这个比例用于近似模拟光线在弯曲表面上的"等效入射角"
 *
 *   行 4：thetaI = asin(x_R_ratio²)
 *     - 将位置比例映射为等效入射角
 *     - 使用平方 (x_R_ratio²) 使角度变化更加非线性
 *     - 物理含义：越靠近边缘（x_R_ratio 小），等效入射角越大
 *
 *   行 5：sinThetaT = sin(thetaI) / refFactor
 *     - 应用斯涅尔定律计算折射角的正弦
 *     - 除以 refFactor：折射率越高，折射角越小（折射越弱）
 *
 *   行 6：if (sinThetaT > 1 || sinThetaT < -1) return 0.0
 *     - 全反射检查：sinThetaT 超出 [-1,1] 范围
 *     - 物理含义：光线在界面处发生全内反射，没有折射光线射出
 *     - 此时返回 0（无折射偏移）
 *
 *   行 7：thetaT = asin(sinThetaT)
 *     - 从正弦值反算折射角
 *
 *   行 8：edgeFactor = -tan(thetaT - thetaI)
 *     - 计算折射导致的光线偏移的切向分量（垂直于法线的方向）
 *     - tan(θT - θI) 是角度差的切向分量
 *     - 负号用于方向对齐
 *
 *   行 9：return max(edgeFactor, 0)
 *     - 确保返回非负值
 *     - 负数表示偏移方向相反，在此处截断为 0
 *
 * 与着色器对应：sdf_utils.inc 中的 computeRefractionEdgeFactor()
 */
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

// =========================================================================
// computeFresnelFactor() - 菲涅尔反射因子
// =========================================================================
/*
 * 算法：计算光线在介质界面上的菲涅尔反射强度
 *
 * 菲涅尔效应：
 *   当视线与表面法线的夹角（入射角）增大时，反射率急剧增大。
 *   这就是为什么看湖面时，远处的湖面反光强烈（掠射角），近处可以看到水下。
 *
 * 公式：
 *   factor = 1 + sdfValue * resolutionY / 1500 * (500/fresnelRange)² + fresnelHardness
 *   result = clamp(factor⁵, 0, 1)
 *
 * 计算流程（逐行）：
 *
 *   行 1：factor = 1 + sdfValue * resolutionY / 1500 * pow(500/fresnelRange, 2) + fresnelHardness
 *
 *     分解理解：
 *     a) sdfValue * resolutionY：将归一化 SDF 转换回像素空间
 *        负值（内部）→ 因子减小，正值（外部）→ 因子增大
 *
 *     b) / 1500：归一化缩放
 *        1500 是参考屏幕高度（≈ 1080p 的合理缩放因子），使得在典型分辨率下
 *        因子值在合理范围内
 *
 *     c) pow(500/fresnelRange, 2)：范围调整项
 *        500 是参考菲涅尔范围
 *        fresnelRange 越小 → 比值越大 → 平方后更大 → 因子更集中在边缘
 *        fresnelRange 越大 → 比值越小 → 平方后更小 → 因子更扩散到中心
 *        平方关系使效果对参数变化更敏感
 *
 *     d) + fresnelHardness：硬度偏移
 *        正值使基础因子增大，导致菲涅尔效果整体增强
 *        这提供了额外的调校自由度
 *
 *   行 2：return clamp(factor⁵, 0, 1)
 *     - 5 次幂使过渡曲线急剧陡峭化
 *     - 这是模拟真实菲涅尔非线性的关键
 *     - 当 factor < 1 时，⁵ 次幂使其迅速趋近 0
 *     - 当 factor > 1 时，⁵ 次幂使其迅速趋近 1
 *     - clamp 确保结果在 [0, 1] 范围内
 *
 * 曲线特性：
 *   factor ≈ 0.8 → factor⁵ ≈ 0.33（大幅衰减）
 *   factor ≈ 1.0 → factor⁵ ≈ 1.0（边界）
 *   factor ≈ 1.2 → factor⁵ ≈ 1.0（被 clamp 截断）
 *
 * 与着色器对应：sdf_utils.inc 中的 computeFresnelFactor()
 */
float computeFresnelFactor(float sdfValue, float fresnelRange, float fresnelHardness, float resolutionY) {
    float factor = 1.0f + sdfValue * resolutionY / 1500.0f * (float)pow(500.0f / fresnelRange, 2.0f) + fresnelHardness;
    return godot::Math::clamp((float)pow(factor, 5.0f), 0.0f, 1.0f);
}

// =========================================================================
// computeGlareGeometryFactor() - 几何眩光因子
// =========================================================================
/*
 * 算法：使用与菲涅尔因子相同的公式，但使用独立的参数组
 *
 * 公式与 computeFresnelFactor() 完全相同，唯一区别是参数来源：
 *   - 菲涅尔使用 fresnelRange + fresnelHardness
 *   - 眩光使用 glareRange + glareHardness
 *
 * 分离设计的理由：
 *   虽然数学上相同，但菲涅尔和眩光服务于不同的视觉目标：
 *   - 菲涅尔：控制反射/透明度（影响背后的内容可见度）
 *   - 眩光：控制高光亮度（叠加在内容之上的发光效果）
 *   分离参数允许美术人员独立调整这两个效果。
 *
 * 与着色器对应：sdf_utils.inc 中的 computeGlareGeometryFactor()
 */
float computeGlareGeometryFactor(float sdfValue, float glareRange, float glareHardness, float resolutionY) {
    float factor = 1.0f + sdfValue * resolutionY / 1500.0f * (float)pow(500.0f / glareRange, 2.0f) + glareHardness;
    return godot::Math::clamp((float)pow(factor, 5.0f), 0.0f, 1.0f);
}

// =========================================================================
// computeGlareAngleFactor() - 角度眩光因子
// =========================================================================
/*
 * 算法：根据表面法线方向与设定光源方向的夹角，计算定向高光强度
 *
 * 这模拟了 Phong/Blinn-Phong 光照模型中的镜面高光，但针对 2D 玻璃效果
 * 做了适配：将法线的极坐标角度映射为正弦函数值，产生定向的光泽效果。
 *
 * 计算流程（逐行）：
 *
 *   行 1：if (normal.length_squared() < 0.0001) return 0.0
 *     - 安全检查：如果法线几乎为零向量（退化情况），返回 0
 *     - 0.0001 是一个很小的阈值，避免除零错误
 *
 *   行 2：n = normal.normalized()
 *     - 确保法线是单位向量
 *
 *   行 3：angle = atan2(n.y, n.x)
 *     - 计算法线在 2D 平面中的极坐标角度
 *     - atan2 返回范围 [-π, π]
 *     - 0 弧度 = 指向右侧
 *
 *   行 4：adjustedAngle = (angle - π/4 + glareAngle) * 2
 *     - 角度调整的三步操作：
 *       a) 减去 π/4（45°）：旋转坐标系，使对角方向（45°线）对齐
 *          这是为了与 tetrahedron 法线计算方法的对称性保持一致
 *       b) 加上 glareAngle：应用用户设定的光源角度偏移
 *          -π/4（默认）= 光源在右上方，产生左下方的眩光
 *       c) 乘以 2：扩展正弦函数的周期，使角度映射更敏感
 *
 *   行 5~8：背面区域（farside）判断
 *     条件：(adjustedAngle > π*(2-0.5) && adjustedAngle < π*(4-0.5))
 *           || adjustedAngle < π*(0-0.5)
 *
 *     简化理解：
 *     - 将 2π（360°）的完整圆划分为区域
 *     - 调整后的角度被映射到一个 4π 的扩展区间（因为乘以 2）
 *     - 上半区间（π*1.5 ~ π*3.5 和 < -π*0.5）对应"背面"
 *     - 在背面区域：glareFarside = 1，眩光较弱（因子 0.8）
 *     - 在正面区域：glareFarside = 0，眩光较强（因子 1.2）
 *
 *   行 9：angleFactor = (0.5 + sin(adjustedAngle) * 0.5) * (farside?0.8:1.2)
 *     - sin(adjustedAngle) 映射到 [-1, 1]
 *     - 0.5 + 0.5*sin(...) 将范围重映射到 [0, 1]
 *     - 乘以 farside 因子：背面 0.8（减弱），正面 1.2（增强）
 *
 *   行 10：return clamp(angleFactor, 0, 1)
 *     - 最终 clamp 确保结果在合法范围内
 *
 * 视觉效果解释：
 *   当法线方向与光源方向对齐时，sin(adjustedAngle) ≈ 1，
 *   产生最大眩光（angleFactor ≈ 1.0），模拟镜面高光的"热点"。
 *   当法线背离光源时，因子减小，眩光减弱。
 *
 * 与着色器对应：sdf_utils.inc 中的 computeGlareAngleFactor()
 */
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
