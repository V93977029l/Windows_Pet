shader_type canvas_item;

// ================================================================
// ██████  液态玻璃史莱姆主着色器 (2号史莱姆)
// ██████
// ================================================================
// 此着色器是液态玻璃演示的核心渲染引擎，实现了基于物理的
// 折射、色散、菲涅尔反射、眩光等光学效果。
//
// 【整体渲染管线架构】
//   本着色器通过 STEP 变量（0~9）分多个阶段渲染，
//   每个 STEP 输出不同的中间结果，用于调试和效果分层：
//
//     STEP 0: SDF 可视化 —— 白色梯度显示距离场
//     STEP 1: SDF 等高线 —— 彩虹色干涉条纹
//     STEP 2: 法线可视化 —— 彩虹色法线方向预览
//     STEP 3~9: 主渲染 —— 完整的折射/色散/菲涅尔/眩光效果
//
// 【主渲染管线（STEP 3~9）的核心物理模拟】
//
//   ┌─────────────────────────────────────────────────────┐
//   │  入射光                                              │
//   │    ↓                                                │
//   │  空气 (n≈1.0)                                       │
//   │ ═══════════════════════════ 玻璃表面                  │
//   │  玻璃 (n≈u_refFactor, 默认1.5)                       │
//   │    ↓ 折射（斯涅尔定律）                               │
//   │    ↓ 色散（不同波长有不同折射率）                      │
//   │    ↓ 菲涅尔反射（掠射角处反射增强）                    │
//   │    ↓ 眩光（内部多次反射产生的亮斑）                    │
//   │    ↓                                                │
//   │  背景图像（被偏移采样，模拟折射偏移）                  │
//   └─────────────────────────────────────────────────────┘
//
//   折射偏移量计算基于斯涅尔定律 (Snell's Law):
//     n₁·sin(θ₁) = n₂·sin(θ₂)
//   其中 n₁=1.0（空气），n₂=u_refFactor（玻璃介质）
//
//   色散模拟基于不同波长的折射率差异:
//     n_R = 0.98 (红光折射率较低，偏折少)
//     n_G = 1.00 (绿光折射率居中)
//     n_B = 1.02 (蓝光折射率较高，偏折多)
//   这导致 RGB 三通道的采样UV有微小的偏移差，
//   产生类似棱镜的色散（chromatic aberration）效果。

// ================================================================
// ██████  色散常数 —— 三通道折射率
// ================================================================
// 这些常量定义了红绿蓝三个颜色通道在玻璃介质中的相对折射率。
//
// 物理背景：
//   在真实光学中，不同波长的光在同一介质中有不同的折射率
//   （这就是棱镜能分解白光的原因）。
//   通常短波长（蓝光）折射率更高，长波长（红光）折射率更低。
//
// 这里的 N_R/N_G/N_B 是相对于基准值的缩放因子（不是绝对折射率）：
//   - N_R = 0.98: 红光折射较少 → 在屏幕上的偏移较小
//   - N_G = 1.00: 绿光作为基准 → 标准偏移
//   - N_B = 1.02: 蓝光折射较多 → 在屏幕上的偏移较大
//
// 视觉效果：RGB三通道微小的偏移差产生彩色边缘（色差/色散），
// 增强玻璃材质的真实感。
const float N_R = 0.98;
const float N_G = 1.0;
const float N_B = 1.02;

// ================================================================
// ██████  最大物品数量
// ================================================================
// 系统最多支持3个史莱姆物品同时显示
// 每个物品可以有独立的位置、尺寸、形状类型等
const int MAX_ITEMS = 3;

// ================================================================
// ██████  SDF 基元函数（与 sdf_utils.inc 中的定义相同）
// ██████
// 这些函数在此着色器中直接内联定义，使得主导色器可以独立编译。
// 详细数学原理请参见 sdf_utils.inc 文件中的注释。
// ================================================================

// ----------------------------------------------------------------
// sdCircle: 圆形 SDF —— 见 sdf_utils.inc 详细注释
// ----------------------------------------------------------------
float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

// ----------------------------------------------------------------
// superellipseCornerSDF: 超椭圆角 SDF —— 见 sdf_utils.inc 详细注释
// ----------------------------------------------------------------
float superellipseCornerSDF(vec2 p, float r, float n) {
    p = abs(p);
    float v = pow(pow(p.x, n) + pow(p.y, n), 1.0 / n);
    return v - r;
}

// ----------------------------------------------------------------
// roundedRectSDF: 超椭圆圆角矩形 SDF —— 见 sdf_utils.inc 详细注释
// ----------------------------------------------------------------
float roundedRectSDF(vec2 p, vec2 center, float width, float height, float cornerRadius, float n, float dpr) {
    p -= center;
    float cr = cornerRadius * dpr;
    vec2 d = abs(p) - vec2(width * dpr, height * dpr) * 0.5;

    float dist;
    if (d.x > -cr && d.y > -cr) {
        vec2 cornerCenter = sign(p) * (vec2(width * dpr, height * dpr) * 0.5 - vec2(cr));
        vec2 cornerP = p - cornerCenter;
        dist = superellipseCornerSDF(cornerP, cr, n);
    } else {
        dist = min(max(d.x, d.y), 0.0) + length(max(d, vec2(0.0)));
    }

    return dist;
}

// ----------------------------------------------------------------
// smin: 平滑最小值 —— 见 sdf_utils.inc 详细注释
// ----------------------------------------------------------------
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// ----------------------------------------------------------------
// bezier3: 三次贝塞尔求值 —— 见 sdf_utils.inc 详细注释
// ----------------------------------------------------------------
vec2 bezier3(vec2 a, vec2 b, vec2 c, vec2 d, float t) {
    float u = 1.0 - t;
    return u*u*u * a + 3.0*u*u*t * b + 3.0*u*t*t * c + t*t*t * d;
}

// ----------------------------------------------------------------
// sdBezier: 贝塞尔曲线 SDF —— 见 sdf_utils.inc 详细注释
// ----------------------------------------------------------------
float sdBezier(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
    float best_t = 0.0;
    float best_d2 = 1e10;

    const int SAMPLES = 12;
    for (int i = 0; i <= SAMPLES; i++) {
        float t = float(i) / float(SAMPLES);
        vec2 q = bezier3(a, b, c, d, t);
        float d2 = dot(q - p, q - p);
        if (d2 < best_d2) { best_d2 = d2; best_t = t; }
    }

    float t = clamp(best_t, 0.0, 1.0);
    for (int i = 0; i < 6; i++) {
        vec2 B = bezier3(a, b, c, d, t);
        float u = 1.0 - t;
        vec2 dB = 3.0*u*u*(b-a) + 6.0*u*t*(c-b) + 3.0*t*t*(d-c);
        vec2 ddB = 6.0*u*(c - 2.0*b + a) + 6.0*t*(d - 2.0*c + b);
        float f = dot(B - p, dB);
        float df = dot(dB, dB) + dot(B - p, ddB);
        if (abs(df) < 1e-9) break;
        t -= f / df;
        t = clamp(t, 0.0, 1.0);
    }
    return length(bezier3(a, b, c, d, t) - p);
}

// ----------------------------------------------------------------
// sdSegment: 线段 SDF —— 见 sdf_utils.inc 详细注释
// ----------------------------------------------------------------
float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// ----------------------------------------------------------------
// halfWidth: 史莱姆半宽度 —— 见 sdf_utils.inc 详细注释
// ----------------------------------------------------------------
float halfWidth(float y, vec2 ru_a, vec2 ru_b, vec2 ru_c, vec2 ru_d,
                        vec2 rl_a, vec2 rl_b, vec2 rl_c, vec2 rl_d) {
    if (y <= 0.11) {
        float lo = 0.0, hi = 1.0;
        for (int i = 0; i < 20; i++) {
            float mid = (lo + hi) * 0.5;
            float ym = bezier3(ru_a, ru_b, ru_c, ru_d, mid).y;
            if (ym < y) { lo = mid; } else { hi = mid; }
        }
        return bezier3(ru_a, ru_b, ru_c, ru_d, (lo+hi)*0.5).x;
    } else {
        float lo = 0.0, hi = 1.0;
        for (int i = 0; i < 20; i++) {
            float mid = (lo + hi) * 0.5;
            float ym = bezier3(rl_a, rl_b, rl_c, rl_d, mid).y;
            if (ym < y) { lo = mid; } else { hi = mid; }
        }
        return bezier3(rl_a, rl_b, rl_c, rl_d, (lo+hi)*0.5).x;
    }
}

// ----------------------------------------------------------------
// sdSlime: 史莱姆形状 SDF —— 见 sdf_utils.inc 详细注释
// ----------------------------------------------------------------
float sdSlime(vec2 p) {
    float ax = abs(p.x);

    float d_ru = sdBezier(vec2(ax, p.y),
        vec2(0.0, -0.231), vec2(0.25, -0.231), vec2(0.4, -0.055), vec2(0.4, 0.11));

    float d_rl = sdBezier(vec2(ax, p.y),
        vec2(0.4, 0.11), vec2(0.4, 0.22), vec2(0.325, 0.275), vec2(0.25, 0.275));

    float d_bt = sdSegment(vec2(ax, p.y), vec2(0.25, 0.275), vec2(-0.25, 0.275));

    float d = min(min(d_ru, d_rl), d_bt);

    bool inside = p.y > -0.232 && p.y < 0.276 && ax <= halfWidth(p.y,
        vec2(0.0, -0.231), vec2(0.25, -0.231), vec2(0.4, -0.055), vec2(0.4, 0.11),
        vec2(0.4, 0.11), vec2(0.4, 0.22), vec2(0.325, 0.275), vec2(0.25, 0.275));

    return inside ? -d : d;
}

// ================================================================
// ██████  UNIFORM 变量说明
// ██████
// ================================================================

// ---------- 输入纹理 ----------

// u_blurredBg: 模糊后的背景纹理（经过分离式高斯模糊处理）
//   用于在玻璃内部的模糊区域采样，模拟透过曲面玻璃看到的模糊背景
uniform sampler2D u_blurredBg;

// u_bg: 原始清晰背景纹理（未经模糊处理）
//   用于在玻璃外部和菲涅尔反射高亮区域采样清晰背景
uniform sampler2D u_bg;

// u_resolution: 渲染分辨率（像素）
//   例: vec2(1920, 1080)
uniform vec2 u_resolution;

// u_dpr: 设备像素比
//   高DPI缩放因子，例: @2x→2.0, @3x→3.0
uniform float u_dpr;

// ---------- 交互参数 ----------

// u_mouse: 鼠标当前位置（像素坐标）
//   用于指向交互效果
uniform vec2 u_mouse;

// u_mouseSpring: 鼠标弹簧模拟位置（带阻尼的平滑跟踪位置）
//   跟踪先前帧的鼠标位置，产生弹性跟随效果
uniform vec2 u_mouseSpring;

// ---------- 形状混合参数 ----------

// u_mergeRate: 物品融合速率
//   传递给 smin 函数的 k 参数，控制多个史莱姆之间的融合过渡宽度
//   0.0 = 尖锐过渡（标准 min），值越大融合越平滑
uniform float u_mergeRate;

// ---------- 多物品参数（支持最多 MAX_ITEMS=3 个物品） ----------

// u_itemPositions: 每个物品的屏幕中心位置（像素坐标）
uniform vec2 u_itemPositions[MAX_ITEMS];

// u_itemWidths: 每个物品的宽度
uniform float u_itemWidths[MAX_ITEMS];

// u_itemHeights: 每个物品的高度
uniform float u_itemHeights[MAX_ITEMS];

// u_itemRadii: 每个物品的圆角半径（对矩形/圆形有不同含义）
uniform float u_itemRadii[MAX_ITEMS];

// u_itemRoundness: 每个物品的超椭圆指数 n
//   n=2→普通圆角, n→∞→矩形角
uniform float u_itemRoundness[MAX_ITEMS];

// u_itemShapeTypes: 每个物品的形状类型
//   0.0 → 圆形
//   1.0 → 超椭圆圆角矩形
//   2.0 → 史莱姆形状
uniform float u_itemShapeTypes[MAX_ITEMS];

// u_itemEnabled: 每个物品是否启用
//   0.0=禁用, 1.0=启用
uniform float u_itemEnabled[MAX_ITEMS];

// u_itemScales: 每个物品的缩放比例
//   1.0=原始大小, >1.0=放大, <1.0=缩小
uniform float u_itemScales[MAX_ITEMS];

// ---------- 颜色与色调 ----------

// u_tint: 全局色调（RGBA）
//   RGB: 基础颜色，alpha: 混合强度
//   例: vec4(0.1, 0.3, 0.6, 1.0) → 蓝色玻璃
uniform vec4 u_tint;

// ---------- 折射参数 ----------

// u_refThickness: 折射厚度（像素单位）
//   定义玻璃的"厚度"——更大的值意味着光线在玻璃中穿行更长的距离
//   影响折射偏移量和折射效果的可见范围
//   视觉效果：厚度越大 → 折射偏移越大 → 背景变形越明显
uniform float u_refThickness;

// u_refFactor: 折射率（绝对折射率 n₂）
//   物理含义：真空/空气中光速与介质中光速之比
//   水的折射率≈1.33，普通玻璃≈1.5，水晶≈1.55，钻石≈2.42
//   默认值≈1.5（模拟普通玻璃）
uniform float u_refFactor;

// u_refDispersion: 色散强度
//   控制 RGB 三通道采样偏移的差异程度
//   0.0 = 无色散（纯折射），1.0 = 最大色散（明显的彩色边缘）
uniform float u_refDispersion;

// ---------- 菲涅尔反射参数 ----------

// u_refFresnelRange: 菲涅尔效应的影响范围
//   控制菲涅尔过渡从边缘向内部延伸多远
//   值越小 → 菲涅尔效果越集中在极边缘
//   值越大 → 菲涅尔效果向内部延伸
uniform float u_refFresnelRange;

// u_refFresnelHardness: 菲涅尔过渡的硬度
//   控制菲涅尔过渡的突然程度
//   值越大 → 过渡越突然（接近阶跃）
//   值越小 → 过渡越平滑
uniform float u_refFresnelHardness;

// u_refFresnelFactor: 菲涅尔反射强度因子
//   整体菲涅尔效果的强度缩放
//   0.0 = 无菲涅尔效果，1.0 = 满强度
uniform float u_refFresnelFactor;

// ---------- 眩光参数 ----------

// u_glareRange: 眩光影响范围
//   控制眩光亮斑的大小和扩散程度
uniform float u_glareRange;

// u_glareConvergence: 眩光收敛度
//   控制眩光亮斑的聚拢程度
//   值越大 → 亮斑越集中（更尖锐的光点）
//   值越小 → 亮斑越扩散（更柔和的光晕）
uniform float u_glareConvergence;

// u_glareOppositeFactor: 背面眩光强度因子
//   控制玻璃背面（远离光源一侧）眩光的额外增强
//   模拟内部反射在对面表面产生的二次高光
uniform float u_glareOppositeFactor;

// u_glareFactor: 眩光整体强度
//   0.0 = 无眩光，1.0 = 满强度眩光
uniform float u_glareFactor;

// u_glareHardness: 眩光硬度
//   控制眩光过渡的锐利程度
uniform float u_glareHardness;

// u_glareAngle: 眩光角度偏移（弧度）
//   旋转眩光亮斑的位置，用于调整光源方向
uniform float u_glareAngle;

// ---------- 渲染控制 ----------

// u_blurEdge: 边缘模糊模式
//   0 = 基于折射深度的渐进模糊
//   1 = 始终使用完全模糊的背景
uniform int u_blurEdge;

// STEP: 渲染阶段选择器（核心调试/分层渲染变量）
//   0: SDF可视化 —— 白色梯度
//   1: SDF等高线 —— 彩色干涉条纹
//   2: 法线可视化 —— 彩虹色法线方向
//   3~9: 主渲染 —— 完整折射/色散/菲涅尔/眩光管线
uniform int STEP;

// ================================================================
// ██████  getItemSDF —— 获取单个物品的 SDF 值
// ██████
// ================================================================
// 此函数将 CPU 端传入的物品参数转换为 SDF 距离值。
//
// 坐标变换链：
//   p (屏幕像素坐标) → pn (归一化坐标，以分辨率为基准)
//
// 形状分支：
//   shapeType < 0.5  → 圆形 (sdCircle)
//   shapeType < 1.5  → 超椭圆圆角矩形 (roundedRectSDF)
//   shapeType ≥ 1.5  → 史莱姆形状 (sdSlime)
//
// 对于史莱姆形状，需要特殊的坐标缩放：
//   先将 pn 从归一化空间缩放到史莱姆的原始 SVG 空间，
//   计算 SDF，然后再缩放回归一化空间。
//   这是因为 sdSlime 在固定的 SVG 坐标系中定义。
//
//   参数: index: 物品索引 (0~MAX_ITEMS-1)
//         p: 屏幕像素坐标
//   返回: SDF 距离值（负数=内部，正数=外部）
float getItemSDF(int index, vec2 p) {
    if (u_itemEnabled[index] < 0.5) {
        return 1.0;  // 禁用的物品返回正值（视为外部）
    }

    vec2 position = u_itemPositions[index];
    float width = u_itemWidths[index];
    float height = u_itemHeights[index];
    float radius = u_itemRadii[index];
    float roundness = u_itemRoundness[index];
    float shapeType = u_itemShapeTypes[index];
    float scale = u_itemScales[index];

    // 将像素坐标转换为归一化坐标（相对于屏幕高度）
    vec2 pn = (p - position) / u_resolution.y;

    if (shapeType < 0.5) {
        // 圆形：半径 * dpr * scale 转换为归一化空间的半径
        return sdCircle(pn, radius * u_dpr * scale / u_resolution.y);
    } else if (shapeType < 1.5) {
        // 超椭圆圆角矩形
        return roundedRectSDF(
            pn,
            vec2(0.0),
            width * scale / u_resolution.y,
            height * scale / u_resolution.y,
            radius * scale / u_resolution.y,
            roundness,
            u_dpr
        );
    } else {
        // 史莱姆形状：
        // sdSlime 在固定的 SVG 坐标空间中工作
        // 需要将当前坐标映射到该空间：除以 (width * dpr * scale)/resolution.y
        // 计算完 SDF 后再缩放回来
        float slimeD = sdSlime(pn * u_resolution.y / (width * u_dpr * scale));
        return slimeD * width * u_dpr * scale / u_resolution.y;
    }
}

// ================================================================
// ██████  mainSDF —— 组合所有物品的 SDF
// ================================================================
// 对所有启用的物品计算 SDF 并使用 smin 进行平滑融合。
//
// 使用 smin（而非普通 min）的原因：
//   当多个史莱姆靠近时，smin 在它们的 SDF 之间产生平滑的
//   混合过渡（metaball 效果），使它们看起来像在融合。
//
//   参数: p: 屏幕像素坐标
//   返回: 组合后的 SDF 距离值
float mainSDF(vec2 p) {
    float result = 1.0;  // 初始化为外部（远距离）

    for (int i = 0; i < MAX_ITEMS; i++) {
        float d = getItemSDF(i, p);
        // 使用 smin 平滑融合，u_mergeRate 控制融合宽度
        result = smin(result, d, u_mergeRate);
    }

    return result;
}

// ================================================================
// ██████  getNormal —— SDF 法线计算
// ================================================================
// 通过对 SDF 进行数值偏微分来计算表面的法线向量。
//
// 数学原理：SDF 的梯度 ∇f = (∂f/∂x, ∂f/∂y) 指向距离增加最快的方向，
// 即指向表面的外侧。对于 SDF 定义的表面，梯度方向 = 表面法线方向。
//
// 数值微分使用中心差分法：
//   ∂f/∂x ≈ [f(x+h,y) - f(x-h,y)] / (2h)
//   ∂f/∂y ≈ [f(x+h,y) - f(x-h,y)] / (2h)  ← 实际使用 h.y 作为Y方向步长
//
// 步长 h 的计算：
//   h = max(dFdx(p), ε)  使用屏幕空间导数来适应不同分辨率
//   dFdx/dFdy 在 GPU 中自动计算相邻像素间的变化率
//
// 返回值乘以 √2*1000 是为了将微小的差分值放大到可视化范围
// （在 STEP 2 法线可视化时使用）
//
//   参数: p: 屏幕像素坐标
//   返回: 缩放后的表面法线向量
vec2 getNormal(vec2 p) {
    vec2 h = vec2(max(abs(dFdx(p.x)), 0.0001), max(abs(dFdy(p.y)), 0.0001));

    vec2 grad = vec2(
        mainSDF(p + vec2(h.x, 0.0)) - mainSDF(p - vec2(h.x, 0.0)),
        mainSDF(p + vec2(0.0, h.y)) - mainSDF(p - vec2(0.0, h.y))
    ) / (2.0 * h);

    return grad * 1.414213562 * 1000.0;
}

// ================================================================
// ██████  hsv2rgb —— HSV 到 RGB 颜色空间转换
// ================================================================
// 使用 Inigo Quilez 的经典HSV→RGB转换公式。
//
// 数学原理：HSV（色相/饱和度/明度）→ RGB 的变换本质上是
// 将色相角度映射到RGB立方体的六个面之一。
//
// 算法通过 vec4 K 预设了相位偏移常量：
//   K = (1, 2/3, 1/3, 3)
// 这个技巧利用了 GLSL 的向量运算一次性完成六个面的映射。
//
//   c: vec3(hue[0~1], saturation[0~1], value[0~1])
//   返回: vec3(r, g, b) 各分量范围 [0, 1]
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// ================================================================
// ██████  颜色科学 —— 完整的色彩空间转换链
// ██████
// ================================================================
//
// 【颜色科学背景知识】
//
// 色彩空间是人类视觉系统、显示设备和数学表示的桥梁。
// 不同的色彩空间适合不同的操作：
//
//   sRGB:   显示设备的标准色彩空间（非线性，带gamma编码）
//           特点：非线性（gamma≈2.2），接近人眼感知
//           适合：最终输出给显示器
//
//   RGB:    线性RGB色彩空间（不依赖特定显示设备）
//           特点：线性（光强度与数值成正比）
//           适合：物理正确的颜色混合和光照计算
//
//   XYZ:    CIE 1931 XYZ —— 人眼色匹配函数的线性组合
//           特点：代表人眼的物理三刺激值
//           适合：作为标准参考空间（所有其他空间的转换中介）
//           Y分量 = 亮度（luminance）
//
//   LAB:    CIE L*a*b* —— 感知均匀色彩空间
//           特点：等距离对应人眼感知的等差异
//           L = 明度（lightness, 0~100）
//           a = 绿-红轴（负→绿, 正→红）
//           b = 蓝-黄轴（负→蓝, 正→黄）
//           适合：在感知层面上操作颜色（如调整亮度而不改变色相）
//
//   LCH:    L*C*h —— LAB的极坐标表示
//           L = 明度（同LAB）
//           C = 色度/饱和度（chroma，距中轴的径向距离）
//           H = 色相角（hue angle, 0~360°）
//           适合：直观地调整色度和色相
//
// 【本着色器中的转换链】
//
//   sRGB (显示颜色)
//     ↓ SRGB_TO_RGB (gamma反压缩)
//   线性RGB (物理线性光强)
//     ↓ RGB_TO_XYZ (矩阵变换)
//   CIE XYZ (三刺激值)
//     ↓ XYZ_TO_LAB (非线性映射)
//   CIE LAB (感知均匀)
//     ↓ LAB_TO_LCH (直角→极坐标)
//   CIE LCH (色相/色度/明度)
//     ↓ 在这里做颜色操作（调整明度L和色度C）
//     ↓ LCH_TO_LAB → LAB_TO_XYZ → XYZ_TO_RGB → RGB_TO_SRGB
//   sRGB (最终输出)
//
// 【为什么需要这么复杂的转换？】
//   在 sRGB 空间中直接增加"亮度"会产生色相偏移和非自然的
//   颜色变化。但在 LCH 空间中：
//     - 增加 L（明度）→ 颜色确实变亮，色相不变
//     - 增加 C（色度）→ 颜色确实更鲜艳，色相不变
//   这对于菲涅尔反射（变亮）和眩光（变亮+增加饱和度）
//   的物理模拟至关重要。

// ----------------------------------------------------------------
// 【D65白点】—— CIE标准光源D65的XYZ三刺激值
// ----------------------------------------------------------------
// D65 是模拟正午日光（色温≈6500K）的标准光源。
// XYZ 中 Y=1.0 对应最大亮度，X=0.9505 和 Z=1.0891
// 是 D65 光源在 CIE 1931 标准观察者下的归一化三刺激值。
const vec3 D65_WHITE = vec3(0.95045592705, 1.0, 1.08905775076);

// ----------------------------------------------------------------
// 【RGB_TO_XYZ_M】—— 线性sRGB → CIE XYZ 的转换矩阵
// ----------------------------------------------------------------
// 此矩阵将线性sRGB原色映射到 CIE 1931 XYZ 三刺激值空间。
// 矩阵系数来源于 sRGB 原色在 XYZ 空间中的坐标。
//
// 矩阵的每一行对应一个 XYZ 分量对 R、G、B 的权重：
//   X = 0.4124R + 0.3576G + 0.1805B
//   Y = 0.2126R + 0.7152G + 0.0722B  ← 亮度（G贡献最大，符合人眼）
//   Z = 0.0193R + 0.1192G + 0.9505B
const mat3 RGB_TO_XYZ_M = mat3(
    vec3(0.4124, 0.2126, 0.0193),
    vec3(0.3576, 0.7152, 0.1192),
    vec3(0.1805, 0.0722, 0.9505)
);

// ----------------------------------------------------------------
// 【XYZ_TO_RGB_M】—— CIE XYZ → 线性sRGB 的逆转换矩阵
// ----------------------------------------------------------------
// RGB_TO_XYZ_M 的逆矩阵，将 XYZ 三刺激值转回线性sRGB。
const mat3 XYZ_TO_RGB_M = mat3(
    vec3(3.2406255, -0.9689307, 0.0557101),
    vec3(-1.537208, 1.8757561, -0.2040211),
    vec3(-0.4986286, 0.0415175, 1.0569959)
);

// ----------------------------------------------------------------
// UNCOMPAND_SRGB —— sRGB Gamma 解压缩（非线性→线性）
// ----------------------------------------------------------------
// 将 sRGB 非线性编码值转换为线性光强值。
//
// sRGB 的 Gamma 曲线是一个分段函数：
//   - 暗部（≤0.04045）：线性段，避免暗部噪声放大
//     y = x / 12.92
//   - 亮部（>0.04045）：幂函数段，近似 gamma 2.4
//     y = ((x + 0.055) / 1.055)^2.4
//
//   参数: a: sRGB 编码值 [0, 1]
//   返回: 线性光强值 [0, 1]
float UNCOMPAND_SRGB(float a) {
    return a > 0.04045 ? pow((a + 0.055) / 1.055, 2.4) : a / 12.92;
}

// ----------------------------------------------------------------
// COMPAND_RGB —— sRGB Gamma 压缩（线性→非线性）
// ----------------------------------------------------------------
// 将线性光强值转换为 sRGB 非线性编码值。
//
// 与 UNCOMPAND_SRGB 互为反函数：
//   - 暗部（≤0.0031308）：线性段
//     y = 12.92 * x
//   - 亮部（>0.0031308）：幂函数段
//     y = 1.055 * x^(1/2.4) - 0.055
//     （注意：1/2.4 ≈ 0.416667）
//
//   参数: a: 线性光强值 [0, 1]
//   返回: sRGB 编码值 [0, 1]
float COMPAND_RGB(float a) {
    return a <= 0.0031308 ? 12.92 * a : 1.055 * pow(a, 0.41666666666) - 0.055;
}

// ----------------------------------------------------------------
// SRGB_TO_RGB —— sRGB → 线性RGB（逐分量Gamma解压）
// ----------------------------------------------------------------
vec3 SRGB_TO_RGB(vec3 srgb) {
    return vec3(UNCOMPAND_SRGB(srgb.x), UNCOMPAND_SRGB(srgb.y), UNCOMPAND_SRGB(srgb.z));
}

// ----------------------------------------------------------------
// RGB_TO_SRGB —— 线性RGB → sRGB（逐分量Gamma压缩）
// ----------------------------------------------------------------
vec3 RGB_TO_SRGB(vec3 rgb) {
    return vec3(COMPAND_RGB(rgb.x), COMPAND_RGB(rgb.y), COMPAND_RGB(rgb.z));
}

// ----------------------------------------------------------------
// RGB_TO_XYZ —— 线性RGB → CIE XYZ（矩阵乘法）
// ----------------------------------------------------------------
vec3 RGB_TO_XYZ(vec3 rgb) {
    return rgb * RGB_TO_XYZ_M;
}

// ----------------------------------------------------------------
// XYZ_TO_RGB —— CIE XYZ → 线性RGB（逆矩阵乘法）
// ----------------------------------------------------------------
vec3 XYZ_TO_RGB(vec3 xyz) {
    return xyz * XYZ_TO_RGB_M;
}

// ----------------------------------------------------------------
// XYZ_TO_LAB_F —— XYZ→LAB 转换中的非线性映射函数
// ----------------------------------------------------------------
// LAB色彩空间的核心是把XYZ三刺激值的比值映射到感知均匀空间。
// 这个非线性函数的作用是模拟人眼对亮度的感知（Weber-Fechner定律的近似）。
//
// 分段定义：
//   - x >  0.008856: f(x) = x^(1/3)  （立方根，暗部以上的正常映射）
//   - x ≤ 0.008856: f(x) = 7.787x + 0.1379  （线性段，处理非常暗的值）
//
// 阈值 0.008856 = (6/29)³，是精心设计的断点。
//
//   参数: x: XYZ比值（X/Xn 或 Y/Yn 或 Z/Zn）
//   返回: 非线性映射后的值
float XYZ_TO_LAB_F(float x) {
    return x > 0.00885645167 ? pow(x, 0.333333333) : 7.78703703704 * x + 0.13793103448;
}

// ----------------------------------------------------------------
// LAB_TO_XYZ_F —— XYZ_TO_LAB_F 的反函数
// ----------------------------------------------------------------
float LAB_TO_XYZ_F(float x) {
    return x > 0.206897 ? x * x * x : 0.12841854934 * (x - 0.137931034);
}

// ----------------------------------------------------------------
// XYZ_TO_LAB —— CIE XYZ → CIE LAB
// ----------------------------------------------------------------
// 完整转换公式：
//   L = 116 * f(Y/Yn) - 16
//   a = 500 * (f(X/Xn) - f(Y/Yn))    ← 绿(-) ↔ 红(+)
//   b = 200 * (f(Y/Yn) - f(Z/Zn))    ← 蓝(-) ↔ 黄(+)
//
// 其中 Xn, Yn, Zn 是参考白点（D65_WHITE）的三刺激值。
//
//   参数: xyz: CIE XYZ 三刺激值
//   返回: vec3(L, a, b) —— L范围[0,100], a和b范围约[-100,+100]
vec3 XYZ_TO_LAB(vec3 xyz) {
    vec3 xyz_scaled = xyz / D65_WHITE;
    xyz_scaled = vec3(XYZ_TO_LAB_F(xyz_scaled.x), XYZ_TO_LAB_F(xyz_scaled.y), XYZ_TO_LAB_F(xyz_scaled.z));
    return vec3(116.0 * xyz_scaled.y - 16.0, 500.0 * (xyz_scaled.x - xyz_scaled.y), 200.0 * (xyz_scaled.y - xyz_scaled.z));
}

// ----------------------------------------------------------------
// LAB_TO_XYZ —— CIE LAB → CIE XYZ（XYZ_TO_LAB的逆变换）
// ----------------------------------------------------------------
vec3 LAB_TO_XYZ(vec3 Lab) {
    float w = (Lab.x + 16.0) / 116.0;
    return D65_WHITE * vec3(LAB_TO_XYZ_F(w + Lab.y / 500.0), LAB_TO_XYZ_F(w), LAB_TO_XYZ_F(w - Lab.z / 200.0));
}

// ----------------------------------------------------------------
// SRGB_TO_LAB —— 便捷组合：sRGB → LAB（经过RGB和XYZ中转）
// ----------------------------------------------------------------
vec3 SRGB_TO_LAB(vec3 srgb) {
    return XYZ_TO_LAB(RGB_TO_XYZ(SRGB_TO_RGB(srgb)));
}

// ----------------------------------------------------------------
// LAB_TO_SRGB —— 便捷组合：LAB → sRGB
// ----------------------------------------------------------------
vec3 LAB_TO_SRGB(vec3 lab) {
    return RGB_TO_SRGB(XYZ_TO_RGB(LAB_TO_XYZ(lab)));
}

// ----------------------------------------------------------------
// LAB_TO_LCH —— CIE LAB → CIE LCH（直角坐标→极坐标）
// ----------------------------------------------------------------
// 将 LAB 的直角坐标 (L, a, b) 转换为 LCH 极坐标 (L, C, h):
//
//   L 保持不变（明度）
//   C = sqrt(a² + b²)                     ← 色度（距中轴的径向距离）
//   h = atan(b, a) * 180/π               ← 色相角（度，0~360）
//
// 为什么乘以 57.2957795131 (=180/π)？
//   将弧度转换为度数，使色相角更直观：0°→红, 120°→绿, 240°→蓝
//
//   参数: Lab: CIE LAB 向量
//   返回: vec3(L, C, h) —— L同前, C≥0, h范围[0,360)
vec3 LAB_TO_LCH(vec3 Lab) {
    return vec3(Lab.x, sqrt(dot(Lab.yz, Lab.yz)), atan(Lab.z, Lab.y) * 57.2957795131);
}

// ----------------------------------------------------------------
// LCH_TO_LAB —— CIE LCH → CIE LAB（极坐标→直角坐标）
// ----------------------------------------------------------------
// 逆变换：
//   a = C * cos(h * π/180)
//   b = C * sin(h * π/180)
//
// 0.01745329251 = π/180（度转弧度）
//
//   参数: LCh: CIE LCH 向量
//   返回: CIE LAB 向量
vec3 LCH_TO_LAB(vec3 LCh) {
    return vec3(LCh.x, LCh.y * cos(LCh.z * 0.01745329251), LCh.y * sin(LCh.z * 0.01745329251));
}

// ----------------------------------------------------------------
// LCH_TO_SRGB —— 便捷组合：LCH → sRGB（完整链路反向）
// ----------------------------------------------------------------
vec3 LCH_TO_SRGB(vec3 lch) {
    return LAB_TO_SRGB(LCH_TO_LAB(lch));
}

// ================================================================
// ██████  vec2ToAngle —— 2D向量转角度
// ================================================================
// 将2D方向向量转换为 [0, 2π) 的角度值。
//
// atan(y, x) 返回范围 [-π, π]，
// 通过 if (angle < 0) angle += 2π 将范围规范化为 [0, 2π)。
//
//   参数: v: 2D方向向量
//   返回: 角度值（弧度），范围 [0, 2π)
float vec2ToAngle(vec2 v) {
    float angle = atan(v.y, v.x);
    return angle < 0.0 ? angle + 2.0 * PI : angle;
}

// ================================================================
// ██████  getTextureDispersion —— 色散纹理采样
// ██████
// ================================================================
// 核心功能：对两个纹理分别按 RGB 三通道的不同偏移采样，
// 然后混合两个纹理的结果。
//
// 【色散的物理模拟】
//
//   不同波长的光在介质中有不同的折射率 → 不同的偏折角度
//   → 在屏幕上产生不同位置的采样偏移 → 彩色边缘
//
//   偏移公式：
//     offset_R = offset * (1.0 - (N_R - 1.0) * factor)
//     offset_G = offset * (1.0 - (N_G - 1.0) * factor)
//     offset_B = offset * (1.0 - (N_B - 1.0) * factor)
//
//   当 factor=0:  所有通道偏移相同（无色散）
//   当 factor>0:  由于 N_R<N_G<N_B:
//     R 通道偏移最小 → 红光偏折最少
//     G 通道偏移居中 → 绿光偏折居中
//     B 通道偏移最大 → 蓝光偏折最多
//
//   视觉效果：在折射边缘产生"红-蓝"色带（类似色差/紫边效果）
//
//   参数:
//     tex1:    清晰背景纹理
//     tex2:    模糊背景纹理
//     mixRate: 两个纹理的混合比例（0=全清晰, 1=全模糊）
//     offset:  基础折射偏移向量（通常为负数 * 法线方向）
//     factor:  色散强度（0=无色散, 1=最大色散）
//     uv:      基础UV坐标
//   返回:
//     带色散的混合纹理颜色（RGB三通道分别偏移采样）
vec4 getTextureDispersion(sampler2D tex1, sampler2D tex2, float mixRate, vec2 offset, float factor, vec2 uv) {
    // 为RGB三个通道分别计算不同的UV偏移
    float bgR = texture(tex1, uv + offset * (1.0 - (N_R - 1.0) * factor)).r;
    float bgG = texture(tex1, uv + offset * (1.0 - (N_G - 1.0) * factor)).g;
    float bgB = texture(tex1, uv + offset * (1.0 - (N_B - 1.0) * factor)).b;

    float blurR = texture(tex2, uv + offset * (1.0 - (N_R - 1.0) * factor)).r;
    float blurG = texture(tex2, uv + offset * (1.0 - (N_G - 1.0) * factor)).g;
    float blurB = texture(tex2, uv + offset * (1.0 - (N_B - 1.0) * factor)).b;

    // 对每个通道分别混合清晰和模糊纹理
    return vec4(mix(bgR, blurR, mixRate), mix(bgG, blurG, mixRate), mix(bgB, blurB, mixRate), 1.0);
}

// ================================================================
// ██████  FRAGMENT 着色器 —— 主渲染
// ██████
// ================================================================
// 此着色器是整个液态玻璃渲染的大脑。
// 它通过 STEP 控制渲染阶段，主渲染（STEP 3~9）实现：
//
//   1. SDF 形状计算（mainSDF）
//   2. 折射模拟（斯涅尔定律）
//   3. 色散模拟（RGB三通道分离采样）
//   4. 菲涅尔反射（掠射角高亮）
//   5. 眩光模拟（内部反射亮斑）
//   6. 抗锯齿（屏幕空间导数混合）
void fragment() {
    // ========== 计算1x分辨率画布尺寸 ==========
    vec2 resolution1x = u_resolution.xy / u_dpr;

    // ========== 计算当前像素的组合SDF值 ==========
    float merged = mainSDF(FRAGCOORD.xy);

    vec4 outColor;

    // ================================================================
    // ██████  STEP 0: SDF 可视化 —— 白色梯度
    // ================================================================
    // 将 SDF 值映射为白色梯度：
    //   - 外部 (merged > 0): 白色 * merged（距离越远越白）
    //   - 内部 (merged < 0): 白色 * |merged| * 2（内部亮度翻倍）
    //   - 在边界处 (merged ≈ 0): 经过 smoothstep 反走样混合到纯白
    //
    // 这个调试视图帮助验证 SDF 计算是否正确：
    //   内部是亮白色，外部是渐变的灰色
    //   边界处有一条清晰的过渡线
    if (STEP <= 0) {
        float px = 2.0 / u_resolution.y;  // 1像素宽度的近似值
        vec3 col = merged > 0.0 ? vec3(1.0) * merged : vec3(1.0) * -merged * 2.0;
        col *= 3.0;  // 亮度增强
        // 在边界处混合到纯白（抗锯齿 + 等高线高亮）
        col = mix(col, vec3(1.0), 1.0 - smoothstep(0.5 / resolution1x.y - px, 0.5 / resolution1x.y + px, abs(merged)));
        outColor = vec4(col, 1.0);
    }
    // ================================================================
    // ██████  STEP 1: SDF 等高线 —— 彩色干涉条纹
    // ================================================================
    // 使用橙色（外部）和蓝色（内部）区分内外，
    // 并叠加余弦条纹来显示 SDF 的等距线（等高线）。
    //
    // 等高线原理：
    //   cos(0.25 * |merged| * resolution1x.y * 2.0)
    //   → 当 merged 变化时产生振荡，形成干涉条纹
    //   → 条纹间距 = 2π / (0.25 * resolution1x.y * 2) 像素
    else if (STEP <= 1) {
        float px = 2.0 / u_resolution.y;
        // 外部橙色暖色调，内部蓝色冷色调
        vec3 col = merged > 0.0 ? vec3(0.9, 0.6, 0.3) : vec3(0.65, 0.85, 1.0);
        // 指数衰减：距离边界越远，颜色越淡
        col *= 1.0 - exp(-0.03 * abs(merged) * resolution1x.y);
        // 余弦条纹叠加：产生干涉图案，显示等距线
        col *= 0.6 + 0.4 * smoothstep(-0.5, 0.5, cos(0.25 * abs(merged) * resolution1x.y * 2.0));
        // 边界处混合到纯白
        col = mix(col, vec3(1.0), 1.0 - smoothstep(1.5 / resolution1x.y - px, 1.5 / resolution1x.y + px, abs(merged)));
        outColor = vec4(col, 1.0);
    }
    // ================================================================
    // ██████  STEP 2: 法线可视化
    // ================================================================
    // 将法线方向编码为彩虹色：
    //   法线角度 → 色相（0°→红, 120°→绿, 240°→蓝）
    //   alpha = 法线长度（仅在表面附近有值）
    //
    // 这用于验证 getNormal() 计算是否正确：
    //   平滑的彩虹色过渡 = 法线连续
    //   断裂/跳变 = 法线计算有问题
    else if (STEP <= 2) {
        if (merged < 0.0) {
            vec2 normal = getNormal(FRAGCOORD.xy);
            float angle = atan(normal.y, normal.x);
            float hue = (angle < 0.0 ? angle + 2.0 * PI : angle) / (2.0 * PI);
            vec3 normalColor = hsv2rgb(vec3(hue, 1.0, 1.0));
            outColor = vec4(normalColor, length(normal));
        } else {
            outColor = vec4(vec3(0.8), 0.0);  // 外部：半透明灰色
        }
    }
    // ================================================================
    // ██████  STEP 3~9: 主渲染管线 —— 折射/色散/菲涅尔/眩光
    // ================================================================
    //
    // 【渲染管线总览】
    //
    //   ┌──────────────────────────────────────────────┐
    //   │ 输入: merged = mainSDF(pixel)                  │
    //   │                                                │
    //   │ 1. 折射偏移计算（斯涅尔定律）                    │
    //   │    ├─ x_R_ratio = 1 - depth/thickness          │
    //   │    ├─ θI = asin(x_R_ratio²)     ← 入射角      │
    //   │    ├─ sinθT = (1/n) * sinθI     ← 斯涅尔定律   │
    //   │    └─ edgeFactor = -tan(θT-θI)  ← UV偏移量    │
    //   │                                                │
    //   │ 2. 色散纹理采样（RGB三通道分离）                 │
    //   │    └─ getTextureDispersion(bg, blurred, ...)   │
    //   │                                                │
    //   │ 3. 色调混合（玻璃着色）                          │
    //   │    └─ mix(sampledColor, tint, tint.a * 0.8)    │
    //   │                                                │
    //   │ 4. 菲涅尔反射（LCH空间明度增强）                 │
    //   │    ├─ fresnelFactor = 掠射角强度              │
    //   │    ├─ 转换到 LCH，增加 L（明度）               │
    //   │    └─ mix 回最终颜色                            │
    //   │                                                │
    //   │ 5. 眩光模拟（LCH空间明度+色度增强）              │
    //   │    ├─ glareGeoFactor = 几何强度                │
    //   │    ├─ glareAngleFactor = 角度方向强度          │
    //   │    ├─ 转换到 LCH，增加 L 和 C                  │
    //   │    └─ mix 回最终颜色                            │
    //   │                                                │
    //   │ 6. 抗锯齿                                      │
    //   │    └─ smoothstep(dFdx,dFdy) 混合到清晰背景     │
    //   └──────────────────────────────────────────────┘
    else if (STEP <= 9) {
        if (merged < 0.005) {
            // ====== 像素在形状内部（或非常接近边界） ======

            // 将SDF距离值转换为正深度值（像素单位）
            float nmerged = -merged * resolution1x.y;

            // ----------------------------------------------------
            // 【步骤1：折射偏移计算（简化的斯涅尔定律模型）】
            // ----------------------------------------------------
            // 这里使用了一个简化的折射模型，不直接使用斯涅尔定律的
            // 完整公式，而是通过几何关系推导UV偏移量。
            //
            // x_R_ratio = 1 - depth/thickness
            //   当 depth=0（表面） → x_R_ratio=1 → 折射为0
            //   当 depth=thickness（最深处） → x_R_ratio=0 → 最大折射
            //   这模拟了光线在曲面不同深度处的入射角变化
            float x_R_ratio = 1.0 - nmerged / u_refThickness;

            // θI（入射角）：从几何关系推导
            // asin(x_R_ratio²) 近似模拟了从表面到内部的入射角变化
            float thetaI = asin(pow(x_R_ratio, 2.0));

            // 斯涅尔定律：n₁·sin(θ₁) = n₂·sin(θ₂)
            // n₁=1.0（空气）, n₂=u_refFactor（玻璃）
            // sin(θ_T) = sin(θ_I) / n₂
            float sinThetaT = (1.0 / u_refFactor) * sin(thetaI);

            // edgeFactor：UV偏移量（负值表示像素被向内推移）
            // 仅当全反射条件不满足时计算
            float edgeFactor = 0.0;
            if (sinThetaT >= -1.0 && sinThetaT <= 1.0 && nmerged < u_refThickness) {
                float thetaT = asin(sinThetaT);
                // -tan(θT-θI) → 光线偏折导致的屏幕空间偏移
                // 负号表示像素被"拉向"边缘内部
                edgeFactor = -tan(thetaT - thetaI);
            }

            // ----------------------------------------------------
            // 【步骤2：背景采样（色散 + 模糊混合）】
            // ----------------------------------------------------
            if (edgeFactor <= 0.0) {
                // 无折射偏移 → 直接使用模糊背景 + 色调
                outColor = texture(u_blurredBg, UV);
                outColor = mix(outColor, vec4(u_tint.rgb, 1.0), u_tint.a * 0.8);
            } else {
                // 有折射偏移 → 进行色散纹理采样

                // edgeH: 深度比例（0=表面, 1=最深处）
                float edgeH = nmerged / u_refThickness;

                // 计算表面法线
                vec2 normal = getNormal(FRAGCOORD.xy);

                // 色散采样：
                //   - 使用 getTextureDispersion 对RGB通道分别偏移
                //   - 偏移方向 = -normal（指向内部）
                //   - 偏移量 = edgeFactor * 0.05 * dpr（缩放到合适的像素范围）
                //   - 额外的宽高比校正：vec2(resolution.y/(resolution1x.x*dpr), 1.0)
                //     补偿非正方形像素（通常 dpr 处理了，但额外保险）
                vec4 blurredPixel = getTextureDispersion(
                    u_bg,
                    u_blurredBg,
                    u_blurEdge > 0 ? 1.0 : edgeH,  // 模糊模式选择
                    -normal * edgeFactor * 0.05 * u_dpr * vec2(u_resolution.y / (resolution1x.x * u_dpr), 1.0),
                    u_refDispersion,
                    UV
                );

                // 混合玻璃色调
                outColor = mix(blurredPixel, vec4(u_tint.rgb, 1.0), u_tint.a * 0.8);

                // ----------------------------------------------------
                // 【步骤3：菲涅尔反射】
                // ----------------------------------------------------
                // 物理原理：当光线以掠射角（接近与表面平行）入射时，
                // 反射率急剧增加。这就是为什么看玻璃边缘比看正面更亮
                // （边缘反射更多环境光）。
                //
                // fresnelFactor 的计算基于 SDF 深度值：
                //   merged 接近0（在表面） → fresnelFactor 大
                //   merged 远离0（在内部深处） → fresnelFactor 小
                //
                // pow(1.0 + merged * resolution1x.y / 1500.0 * pow(500/u_range, 2) + hardness, 5.0)
                //   这是经验公式，模拟了菲涅尔反射对表面曲率的响应
                float fresnelFactor = clamp(
                    pow(1.0 + merged * resolution1x.y / 1500.0 * pow(500.0 / u_refFresnelRange, 2.0) + u_refFresnelHardness, 5.0),
                    0.0, 1.0
                );

                // 在 LCH 空间中增加明度（L）
                // 为什么在 LCH 空间操作？
                //   → 在 sRGB 中直接加白会改变色相
                //   → 在 LCH 中增加 L 只会让颜色变亮，保持色相不变
                //   → 这是物理上更正确的"变亮"操作
                vec3 fresnelTintLCH = SRGB_TO_LAB(mix(vec3(1.0), u_tint.rgb, u_tint.a * 0.5));
                fresnelTintLCH.x += 20.0 * fresnelFactor * u_refFresnelFactor;  // 增加明度
                fresnelTintLCH.x = clamp(fresnelTintLCH.x, 0.0, 100.0);  // 限制在有效范围
                // 将菲涅尔增亮后的颜色混入输出（混合权重受法线长度调节）
                outColor = mix(outColor, vec4(LCH_TO_SRGB(fresnelTintLCH), 1.0), fresnelFactor * u_refFresnelFactor * 0.7 * length(normal));

                // ----------------------------------------------------
                // 【步骤4：眩光模拟】
                // ----------------------------------------------------
                // 眩光（glare）是光线在玻璃内部多次反射后，
                // 在某些角度聚集产生的亮斑。与菲涅尔反射的表面反射不同，
                // 眩光来自内部反射的累积效应。
                //
                // 眩光有两个强度因子：
                //
                //   a) glareGeoFactor（几何因子）：
                //      基于 SDF 深度，靠近边缘更强
                //      使用与菲涅尔类似的公式，但有不同的范围参数
                float glareGeoFactor = clamp(
                    pow(1.0 + merged * resolution1x.y / 1500.0 * pow(500.0 / u_glareRange, 2.0) + u_glareHardness, 5.0),
                    0.0, 1.0
                );

                //   b) glareAngleFactor（角度因子）：
                //      基于法线方向，在某些特定角度产生亮斑
                //      模拟内部反射在特定方向的聚集
                //
                // glareAngleRad: 将法线角度映射到眩光角度空间
                //   - PI/4 偏移使眩光中心位于右上方（模拟左上光源）
                //   + u_glareAngle 允许用户旋转眩光方向
                //   * 2.0 将角度周期缩短为π（半周期）
                float glareAngleRad = (vec2ToAngle(normalize(normal)) - PI / 4.0 + u_glareAngle) * 2.0;

                // glareFarside: 检测是否在"背面"
                //   当眩光角度在特定范围时标记为背面
                //   背面眩光使用 u_glareOppositeFactor 进行额外增强
                int glareFarside = 0;
                if ((glareAngleRad > PI * (2.0 - 0.5) && glareAngleRad < PI * (4.0 - 0.5)) || glareAngleRad < PI * (0.0 - 0.5)) {
                    glareFarside = 1;
                }

                // 眩光角度强度：使用正弦函数产生角度依赖的强度变化
                // (0.5 + sin(angle)*0.5) → 范围 [0, 1]，在特定角度达到峰值
                float glareAngleFactor = (0.5 + sin(glareAngleRad) * 0.5) * (glareFarside == 1 ? 1.2 * u_glareOppositeFactor : 1.2) * u_glareFactor;
                // 使用幂函数调整眩光亮斑的锐利程度
                glareAngleFactor = clamp(pow(glareAngleFactor, 0.1 + u_glareConvergence * 2.0), 0.0, 1.0);

                // 在 LCH 空间中增加明度（L）和色度（C）
                //   增加 L → 颜色变亮（眩光的主要效果）
                //   增加 C → 饱和度增加（眩光处颜色更鲜艳）
                vec3 glareTintLCH = SRGB_TO_LAB(mix(blurredPixel.rgb, u_tint.rgb, u_tint.a * 0.5));
                glareTintLCH.x += 150.0 * glareAngleFactor * glareGeoFactor;  // 明度大幅增加
                glareTintLCH.y += 30.0 * glareAngleFactor * glareGeoFactor;    // 色度小幅增加
                glareTintLCH.x = clamp(glareTintLCH.x, 0.0, 120.0);

                // 将眩光混入输出（混合权重受法线长度调节）
                outColor = mix(outColor, vec4(LCH_TO_SRGB(glareTintLCH), 1.0), glareAngleFactor * glareGeoFactor * length(normal));
            }
        } else {
            // 像素在形状外部 → 直接采样清晰背景
            outColor = texture(u_bg, UV);
        }

        // ====== 抗锯齿处理 ======
        // 使用屏幕空间偏导数计算 SDF 的局部变化率
        // aaWidth: 基于梯度大小的自适应抗锯齿宽度
        // sqrt(dx²+dy²) 是 SDF 的梯度大小（变化快慢）
        float dx = dFdx(merged);
        float dy = dFdy(merged);
        float aaWidth = sqrt(dx * dx + dy * dy) * 2.0;
        // smoothstep: 在边界区域平滑过渡到清晰背景
        outColor = mix(outColor, texture(u_bg, UV), smoothstep(-aaWidth, aaWidth, merged));
    }

    COLOR = outColor;
}