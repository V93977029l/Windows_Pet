shader_type canvas_item;

// ================================================================
// ██████  分离式高斯模糊着色器
// ██████
// ================================================================
// 此着色器实现「分离式高斯模糊」（Separable Gaussian Blur），
// 是液态玻璃渲染管线的后处理步骤之一。
//
// 【为什么用分离式高斯模糊？】
//
//   标准2D高斯模糊需要对每个像素采样 N×N 的卷积核区域，
//   计算复杂度为 O(N²)。例如 15×15 的核需要每个像素225次纹理采样。
//
//   高斯函数的一个重要数学性质是「可分离性」：
//     G(x,y) = G(x) · G(y)
//   即2D高斯核可以分解为两个1D高斯核的外积。
//
//   这意味着我们可以分两遍（two-pass）完成：
//     第一遍（竖直）：对每列做一维高斯模糊
//     第二遍（水平）：对每行做一维高斯模糊
//   最终的2D模糊效果完全等价，但复杂度降为 O(2N)。
//   对于 15×15 核：从225次降为30次采样，性能提升 7.5 倍！
//
// 【渲染流程】
//   本着色器被调用两次（由 CPU 端控制 u_vertical 参数）：
//     Pass 1 (u_vertical = true):  读取原始背景纹理，沿 Y 轴模糊
//     Pass 2 (u_vertical = false): 读取 Pass 1 输出，沿 X 轴模糊
//   最终输出 = 完整的2D高斯模糊结果
//
//   在主要渲染管线中：
//     原背景 → [竖直模糊] → [水平模糊] → u_blurredBg（被main shader读取）
//
// 【u_blurWeights 预设值说明】
//   CPU 端使用高斯函数公式预计算权重数组：
//     weight[i] = exp(-(offset²) / (2·σ²))
//   其中 σ = blurRadius / 3（经验值，使核覆盖约±3σ范围）
//   权重已在 CPU 端归一化（总和=1），但着色器中仍做保护性归一化

// ----------------------------------------------------------------
// UNIFORM 变量说明
// ----------------------------------------------------------------

// u_prevPassTexture: 上一遍处理的输出纹理
//   Pass 1 时指向原始背景纹理
//   Pass 2 时指向 Pass 1（竖直模糊）的输出
uniform sampler2D u_prevPassTexture;

// u_resolution: 渲染目标的分辨率（像素）
//   用于计算单个像素的 UV 步长（texelSize = 1.0/resolution）
uniform vec2 u_resolution;

// u_dpr: 设备像素比（Device Pixel Ratio）
//   高DPI显示器上此值 > 1（如 Mac Retina 为 2.0）
//   模糊半径会随 DPR 缩放以确保在不同设备上视觉一致
uniform float u_dpr;

// u_blurRadius: 模糊半径（逻辑像素）
//   控制模糊扩散范围：
//     - 1.0：轻微模糊（适合细微的折射模糊）
//     - 5.0：中等模糊（适合玻璃散射效果）
//     - 15.0+：重度模糊（适合强散射/毛玻璃效果）
uniform float u_blurRadius;

// MAX_KERNEL_SIZE: 最大卷积核尺寸（硬编码常量）
//   限制为200以防止性能问题
//   实际使用核尺寸 = min(blurRadius*2+1, 200)
const int MAX_KERNEL_SIZE = 200;

// u_blurWeights: 预计算的1D高斯权重数组（由CPU端传入）
//   数组索引 i=0 对应最左侧/最上方的采样偏移
//   权重已经按高斯函数预计算，总和约为1
//   此数组在两次Pass之间保持不变（1D高斯核可复用）
uniform float u_blurWeights[MAX_KERNEL_SIZE];

// u_vertical: 控制模糊方向的关键开关
//   true  → 沿 Y 轴（竖直方向）模糊
//   false → 沿 X 轴（水平方向）模糊
//   这个简单的布尔值实现了分离式高斯模糊的核心思想
uniform bool u_vertical;

// ================================================================
// ██████  FRAGMENT 着色器 —— 一维加权采样
// ================================================================
// 原理：
//   对于当前像素，沿指定方向（竖直或水平）采样 kernelSize 个相邻像素，
//   每个采样点的权重 = u_blurWeights[i]（高斯权重），
//   将所有加权颜色累加后除以总权重。
//
// 采样模式（以 kernelSize=5, halfKernel=2 为例）：
//   竖直模糊时采样偏移: (0,-2), (0,-1), (0,0), (0,1), (0,2)  ← UV偏移
//   水平模糊时采样偏移: (-2,0), (-1,0), (0,0), (1,0), (2,0)  ← UV偏移
//
// 每个采样位置权重: w₀, w₁, w₂, w₃, w₄（高斯形状：中间大，两边小）
void fragment() {
    // ====== 步骤1：计算单个纹素在UV空间中的步长 ======
    // 1.0/resolution 将一个像素映射到 UV 空间 [0,1]
    // 例如：resolution=(1920,1080) → texelSize=(1/1920, 1/1080)
    vec2 texelSize = 1.0 / u_resolution;

    // ====== 步骤2：初始化累加器 ======
    vec4 color = vec4(0.0);     // 加权颜色累加器
    float totalWeight = 0.0;   // 总权重累加器（用于后续归一化）

    // ====== 步骤3：计算实际使用的一维核尺寸 ======
    // 高斯模糊的核尺寸通常取 2*radius+1（确保覆盖 ±radius 范围）
    // 同时限制在 MAX_KERNEL_SIZE 以内防止性能问题
    int kernelSize = min(int(u_blurRadius * 2.0 + 1.0), MAX_KERNEL_SIZE);
    // halfKernel: 核中心位置（整数除法，截断）
    // 例如 kernelSize=15 → halfKernel=7（中心索引）
    int halfKernel = kernelSize / 2;

    // ====== 步骤4：一维卷积采样循环 ======
    for (int i = 0; i < kernelSize; i++) {
        // 计算当前采样点相对于中心的偏移量
        // offset 范围: [-halfKernel, +halfKernel]
        // 例如 halfKernel=2: offset = -2, -1, 0, 1, 2
        int offset = i - halfKernel;

        // 根据模糊方向构造 UV 偏移向量
        // u_vertical=true:  uvOffset = (0, offset/height)  → 沿 Y 轴
        // u_vertical=false: uvOffset = (offset/width, 0)  → 沿 X 轴
        vec2 uvOffset = u_vertical ? vec2(0.0, float(offset)) : vec2(float(offset), 0.0);

        // 将像素单位偏移转换为 UV 空间偏移
        uvOffset *= texelSize;

        // 获取该采样点的高斯权重（CPU端预计算）
        float weight = u_blurWeights[i];

        // 加权采样：读取邻域像素并乘以高斯权重
        // UV + uvOffset 移动到邻域像素位置
        color += texture(u_prevPassTexture, UV + uvOffset) * weight;

        // 累加总权重（理想情况下≈1.0，但做保护性归一化）
        totalWeight += weight;
    }

    // ====== 步骤5：归一化 ======
    // 由于浮点精度等原因，总权重可能不完全等于1
    // 除以总权重确保结果亮度正确（不会因权重误差而变亮或变暗）
    if (totalWeight > 0.0) {
        color /= totalWeight;
    }

    // ====== 步骤6：输出 ======
    COLOR = color;
}
