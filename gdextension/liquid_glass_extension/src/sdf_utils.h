/*
 * ============================================================================
 * SDF 工具函数命名空间 - 液态玻璃渲染的数学计算核心
 * ============================================================================
 *
 * 【命名空间说明】
 *   LiquidGlassUtils 是一个纯函数命名空间，不包含任何状态。
 *   它封装了所有与 SDF（Signed Distance Function，有符号距离函数）相关的
 *   几何计算和光学模拟算法。这些函数与着色器中的 sdf_utils.inc 文件一一对应，
 *   确保 CPU 端（GDExtension）和 GPU 端（Shader）的计算结果一致。
 *
 * 【架构角色】
 *   LiquidGlassUtils 是底层计算引擎，被 LiquidGlass::compute_xxx() 方法调用。
 *   LiquidGlass (Resource) → LiquidGlassUtils (SDF 引擎)
 *
 * 【SDF 基本概念】
 *   有符号距离函数：对空间中任意一点 p，返回该点到最近表面的距离。
 *   - 负值：点在形状内部
 *   - 正值：点在形状外部
 *   - 零值：点正好在表面上（等值面）
 *
 * 【与着色器的对应关系】
 *   本文件中的每个函数都在 shader/sdf_utils.inc 中有对应的 GLSL 实现，
 *   确保 CPU 端预计算和 GPU 端逐像素计算的结果数学等价。
 */

#ifndef SDF_UTILS_H
#define SDF_UTILS_H

#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/core/math.hpp>

using namespace godot;

namespace LiquidGlassUtils {

/*
 * sdCircle() - 圆形 SDF
 *   数学原型：sdCircle(p, r) = ||p|| - r
 *   参数：p = 相对于圆心的二维坐标向量
 *         r = 圆的半径
 *   返回值：负值 = 点在圆内，正值 = 点在圆外
 *
 *   这是最简单的 SDF 形式，所有更复杂形状的 SDF 都建立在此基础之上。
 *   计算复杂度 O(1)（一次向量长度 + 一次减法）。
 */
float sdCircle(const Vector2& p, float r);

/*
 * superellipseCornerSDF() - 超椭圆角 SDF
 *   数学原型：superellipseSDF(p, r, n) = (|px|^n + |py|^n)^(1/n) - r
 *   参数：p = 相对于角中心的坐标
 *         r = 角的半径
 *         n = 超椭圆指数（形状控制参数）
 *   返回值：SDF 距离值
 *
 *   超椭圆是圆和矩形的中间形态：
 *   - n=2：标准圆角（椭圆）
 *   - n=5：介于方和圆之间的过渡
 *   - n→∞：趋近矩形
 *
 *   计算步骤：
 *   1. 取坐标的绝对值（对称处理）
 *   2. 分别计算 |x|^n 和 |y|^n
 *   3. 求和后开 n 次根
 *   4. 减去半径得到 SDF
 *
 *   性能注意：pow() 是相对昂贵的运算，这里每个角需要调用 3 次 pow。
 */
float superellipseCornerSDF(const Vector2& p, float r, float n);

/*
 * roundedRectSDF() - 圆角矩形 SDF
 *   数学原型：取点相对于矩形中心，然后用超椭圆角处理四个角
 *   参数：p = 查询点坐标
 *         center = 矩形中心坐标
 *         width/height = 矩形宽高
 *         cornerRadius = 圆角半径
 *         roundness = 角形状指数（超椭圆 n 值）
 *   返回值：SDF 距离值
 *
 *   算法思路：
 *   1. 将查询点转换到矩形局部坐标
 *   2. 计算点到矩形边的"超出量" d
 *   3. 如果同时在两轴超出（进入了角部区域）→ 使用超椭圆角计算
 *   4. 否则 → 使用标准矩形 SDF 公式：min(max(dx,dy), 0) + max(d,0).length()
 *
 *   调用链：roundedRectSDF() → superellipseCornerSDF()
 */
float roundedRectSDF(const Vector2& p, const Vector2& center, float width, float height, float cornerRadius, float roundness);

/*
 * smin() - 平滑最小值（Smooth Minimum）
 *   数学原型（Inigo Quilez 的多项式 smin）：
 *     smin(a, b, k) = mix(a, b, h) - k * h * (1 - h)
 *     其中 h = clamp(0.5 + 0.5*(b-a)/k, 0, 1)
 *   参数：a, b = 两个 SDF 值
 *         k = 平滑系数（融合宽度）
 *   返回值：平滑融合后的 SDF 值
 *
 *   用途：将两个独立形状的 SDF 平滑地"焊接"在一起，
 *   产生类似液滴融合的视觉效果。
 *   - k=0：等价于 min(a, b)（硬切换）
 *   - k>0：两个形状之间产生平滑过渡
 *
 *   算法步骤：
 *   1. 计算插值因子 h：基于 b-a 的差值归一化
 *   2. 线性插值 mix(a, b, h)
 *   3. 减去惩罚项 k*h*(1-h) 确保平滑
 *
 *   这是液态玻璃"液态"视觉效果的核心函数。
 */
float smin(float a, float b, float k);

/*
 * mainSDF() - 主 SDF 计算函数
 *   将圆形和圆角矩形两个形状合并为最终的玻璃轮廓 SDF
 *   参数：p1 = 形状1（圆形）的中心位置（已归一化到 [0,1] 空间）
 *         p2 = 形状2（圆角矩形）的中心位置
 *         p = 查询点位置
 *         shapeWidth/Height/Radius/Roundness = 形状参数
 *         mergeRate = 融合平滑度
 *         dpr = 设备像素比
 *         resolutionY = 屏幕垂直分辨率
 *         showShape1 = 是否显示圆形（1=显示, 0=隐藏）
 *   返回值：最终合并后的 SDF 值
 *
 *   调用链：mainSDF() → sdCircle() + roundedRectSDF() + smin()
 *
 *   算法流程：
 *   1. 将形状位置归一化到 [0,1] 空间（除以 resolutionY）
 *   2. 计算圆形 SDF（如果 showShape1 == 1，否则返回 1.0 即完全在外部）
 *   3. 计算圆角矩形 SDF
 *   4. 使用 smin 将两者平滑融合
 *
 *   坐标归一化的目的：使 SDF 值与分辨率无关，确保不同分辨率下效果一致。
 */
float mainSDF(const Vector2& p1, const Vector2& p2, const Vector2& p, float shapeWidth, float shapeHeight, float shapeRadius, float shapeRoundness, float mergeRate, float dpr, float resolutionY, int showShape1);

/*
 * getNormal() - 计算 SDF 表面的法线向量（梯度法）
 *   数学原理：法线 = normalize(∇SDF) = normalize(gradient of SDF)
 *   使用 tetrahedron（四面体）方法，在四个对角方向采样 SDF 值计算梯度。
 *   参数：同 mainSDF 的参数
 *   返回值：归一化的法线向量
 *
 *   梯度计算使用的四方向：
 *   e1 = (+1, +1) 东南方向
 *   e2 = (-1, +1) 西南方向
 *   e3 = (+1, -1) 东北方向
 *   e4 = (-1, -1) 西北方向
 *
 *   梯度 = d1*e1 + d2*e2 + d3*e3 + d4*e4
 *   （其中 d_i 是在偏移 eps*e_i 处采样的 SDF 值）
 *
 *   步长 eps = 0.7071 * 0.0005 ≈ 0.000354
 *   0.7071 = 1/√2 ≈ 对角方向在 xy 轴上的投影系数
 *
 *   调用链：getNormal() → mainSDF() × 4 次采样
 *
 *   与中心差分法的对比：
 *   tetrahedron 方法对旋转对称性更好，减少方向性偏差。
 */
Vector2 getNormal(const Vector2& p1, const Vector2& p2, const Vector2& p, float shapeWidth, float shapeHeight, float shapeRadius, float shapeRoundness, float mergeRate, float dpr, float resolutionY, int showShape1);

/*
 * computeRefractionEdgeFactor() - 计算折射边缘偏移因子
 *   基于斯涅尔定律（Snell's Law）模拟光线穿过玻璃介质的折射
 *   参数：sdfValue = 当前像素的 SDF 值
 *         thickness = 玻璃厚度（refThickness 参数）
 *         refFactor = 折射率（IOR, Index of Refraction）
 *         resolutionY = 屏幕垂直分辨率
 *   返回值：折射偏移量（≥0），0 表示无折射（像素在玻璃外部）
 *
 *   算法步骤（斯涅尔定律模拟）：
 *   1. nmerged = -sdfValue * resolutionY
 *      将 SDF 从 [0,1] 空间转换回像素空间距离
 *   2. 如果 nmerged >= thickness（像素在玻璃外部或完全穿透）→ 返回 0
 *   3. x_R_ratio = 1 - nmerged/thickness
 *      计算像素在玻璃内部的位置比例（0=表面, 1=中心）
 *   4. thetaI = asin(x_R_ratio²)
 *      将位置比例映射为"等效入射角"（二次方模拟曲面效果）
 *   5. sinThetaT = sin(thetaI) / refFactor
 *      斯涅尔定律：n1*sin(θ1) = n2*sin(θ2)，其中 n1=1（空气）
 *   6. 检查全反射条件（sinThetaT > 1）→ 返回 0
 *   7. thetaT = asin(sinThetaT)
 *      计算折射角
 *   8. edgeFactor = -tan(thetaT - thetaI)
 *      折射偏移的切向分量
 *   9. 返回 max(edgeFactor, 0)
 *      确保非负
 */
float computeRefractionEdgeFactor(float sdfValue, float thickness, float refFactor, float resolutionY);

/*
 * computeFresnelFactor() - 计算菲涅尔反射因子
 *   模拟光在介质界面上的菲涅尔反射效应
 *   参数：sdfValue = 当前像素的 SDF 值
 *         fresnelRange = 菲涅尔衰减范围（控制边缘→中心的渐变宽度）
 *         fresnelHardness = 菲涅尔硬度（控制过渡的锐利程度）
 *         resolutionY = 屏幕垂直分辨率
 *   返回值：0~1 之间的菲涅尔强度因子
 *
 *   算法公式：
 *     factor = 1 + sdfValue * resolutionY / 1500 * (500/fresnelRange)² + fresnelHardness
 *     result = clamp(factor⁵, 0, 1)
 *
 *   关键魔法数字：
 *   - 1500：归一化缩放因子，将 SDF 值映射到合理的数值范围
 *   - 500：参考菲涅尔范围，用于参数对比
 *   - (500/fresnelRange)²：平方反比关系，范围越小效果越集中在边缘
 *   - 5 次幂：使过渡曲线更陡峭，模拟真实菲涅尔的非线性特性
 *
 *   物理原理：视线与表面法线夹角越大（越接近掠射角），反射率越高。
 *   SDF 越接近 0（越靠近边缘）→ factor 越大 → 菲涅尔越强。
 */
float computeFresnelFactor(float sdfValue, float fresnelRange, float fresnelHardness, float resolutionY);

/*
 * computeGlareGeometryFactor() - 计算几何眩光因子
 *   参数和算法与 computeFresnelFactor 完全相同，但使用独立的参数组
 *   参数：sdfValue = SDF 值
 *         glareRange = 眩光衰减范围
 *         glareHardness = 眩光硬度
 *         resolutionY = 屏幕垂直分辨率
 *   返回值：0~1 之间的几何眩光强度
 *
 *   分离设计意图：菲涅尔和眩光虽然使用相同的数学模型，但服务于不同的
 *   视觉效果。菲涅尔控制反射强度，眩光控制高光强度。分离参数允许
 *   独立调校两个效果。
 */
float computeGlareGeometryFactor(float sdfValue, float glareRange, float glareHardness, float resolutionY);

/*
 * computeGlareAngleFactor() - 计算角度眩光因子
 *   根据表面法线方向与光源方向的夹角计算定向高光强度
 *   参数：normal = 表面法线向量
 *         glareAngle = 光源主方向角度（弧度）
 *   返回值：0~1 之间的角度眩光强度
 *
 *   算法步骤：
 *   1. 检查法线是否有效（长度平方 > 0.0001）
 *   2. 归一化法线
 *   3. angle = atan2(n.y, n.x)，计算法线的极坐标角度
 *   4. adjustedAngle = (angle - π/4 + glareAngle) * 2
 *      - 减去 π/4：将坐标系统旋转 45°（对角方向对齐）
 *      - 加上 glareAngle：应用用户设定的光源偏移
 *      - 乘以 2：使正弦波的周期加倍，产生对称的高光分布
 *   5. 判断 farside（背面区域）：
 *      使用调整后的角度范围检测法线是否指向光源的背面
 *      背面区域因子 = 0.8（较弱），正面区域因子 = 1.2（较强）
 *   6. angleFactor = 0.5 + sin(adjustedAngle) * 0.5
 *      正弦映射到 [0,1] 范围
 *   7. 返回 clamp(angleFactor, 0, 1)
 *
 *   视觉效果：法线指向光源方向时因子最大（眩光最强），
 *   法线背离光源时因子最小。
 */
float computeGlareAngleFactor(const Vector2& normal, float glareAngle);

}

#endif
