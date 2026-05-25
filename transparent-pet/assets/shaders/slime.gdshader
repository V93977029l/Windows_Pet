shader_type canvas_item;

// ================================================================
// ██████  史莱姆着色器 —— 1号史莱姆（普通蓝色玻璃史莱姆）
// ██████
// ================================================================
// 渲染风格：玻璃质感 + 边缘发光（菲涅尔效果）+ 动态流动变形
//
// 【整体渲染管线概述】
//   vertex() 阶段：对顶点进行正弦波动态形变，产生果冻般的晃动效果
//   fragment() 阶段：
//     1. 噪声扰动 → 模拟玻璃内部的折射/流动
//     2. 纹理采样 → 获取形状遮罩
//     3. 菲涅尔边缘光 → 边缘比中心更亮（玻璃的典型光学特征）
//     4. 高光/镜面反射 → 模拟光源在曲面上的反射
//     5. 中心透明度 → 史莱姆中心更透明（薄处更透光）
// ================================================================

// ================================================================
// ██████  UNIFORM 变量说明
// ================================================================

// 【颜色/外观参数】
// glass_color: 史莱姆的基础玻璃颜色（RGBA）
//   默认值 vec4(0.1, 0.3, 0.6, 1.0) 产生蓝色调
//   修改此值可获得不同颜色的史莱姆（如绿色、紫色等）
//   alpha 通道控制基础不透明度
uniform vec4 glass_color = vec4(0.1, 0.3, 0.6, 1.0);

// edge_glow: 边缘发光强度（范围建议 0.0 ~ 2.0）
//   值越大，边缘发光越亮
//   与 fresnel_power 配合使用控制发光效果
uniform float edge_glow = 0.8;

// highlight_intensity: 高光/镜面反射强度（范围建议 0.0 ~ 2.0）
//   模拟点光源在史莱姆曲面上产生的高光亮斑
//   值越大，高光越刺眼
uniform float highlight_intensity = 1.0;

// 【动态效果参数】
// liquid_wobble: 液体晃动幅度（范围建议 0.0 ~ 1.0）
//   控制顶点形变和纹理噪声扰动的强度
//   0.0 表示完全静止的固体玻璃
//   1.0 表示剧烈晃动的液体
uniform float liquid_wobble = 0.3;

// wobble_speed: 晃动速度（范围建议 0.5 ~ 5.0）
//   控制正弦波的时间频率，即晃动的快慢
//   值越大晃动越快
uniform float wobble_speed = 2.0;

// 【菲涅尔参数】
// fresnel_power: 菲涅尔效果的幂指数（范围建议 1.0 ~ 8.0）
//   控制边缘发光的衰减速度
//   值越小 → 发光范围越宽（整体较亮）
//   值越大 → 发光范围越窄（仅边缘极亮，中心暗）
uniform float fresnel_power = 3.0;

// enable_dynamic: 是否启用动态效果总开关
//   true  → 顶点形变 + 纹理噪声扰动 + 时间变化的颜色噪声
//   false → 完全静态，适合作为预览或性能优化
uniform bool enable_dynamic = true;

// ================================================================
// ██████  噪声函数（Noise Functions）
// ================================================================
// 下方三个函数构建了一个 FBM（分形布朗运动）噪声系统，
// 用于为史莱姆表面添加有机的、自然的纹理扰动。

// ----------------------------------------------------------------
// random —— 伪随机数生成器
// ----------------------------------------------------------------
// 算法：使用正弦-点积哈希（sine-dot hash），这是 GPU 着色器中最
// 常用的伪随机函数。它将2D坐标映射到一个看似随机的 [0,1] 值。
//
// 原理：
//   1. dot(st, vec2(12.9898, 78.233)) → 将2D坐标投影到"魔法方向"
//      （这两个常数是精心挑选的，能产生良好的分布）
//   2. sin(...) → 利用正弦函数的混沌特性产生伪随机
//   3. fract(... * 43758.5453) → 取小数部分，将大数映射到 [0,1]
//
// 这种哈希的特点是：
//   - 快速：仅需3个基本运算
//   - 确定性的：相同输入永远返回相同输出
//   - 看似随机但实际是纯数学函数
//
//   st: 2D输入坐标（通常为整数网格坐标）
//   返回: 伪随机值，范围 [0, 1]
float random(vec2 st) {
    return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453);
}

// ----------------------------------------------------------------
// noise —— 2D 值噪声（Value Noise）
// ----------------------------------------------------------------
// 算法：经典的四角双线性插值噪声。
//
// 原理（晶格噪声）：
//   1. floor(st) → 将连续坐标映射到整数晶格（当前格子左下角）
//   2. fract(st) → 获取晶格内的相对位置（小数部分）
//   3. 对四个角（a,b,c,d）分别调用 random() 获取随机值
//   4. u = f*f*(3-2f) → Hermite 平滑曲线（smoothstep 的等价形式）
//      —— 消除晶格边界的 C¹ 不连续性
//   5. 双线性插值：mix(a,b,u.x) + (c-a)*u.y*(1-u.x) + (d-b)*u.x*u.y
//      —— 在四个角值之间平滑过渡
//
//   特点：产生平滑连续的噪声值，比白噪声有"结构感"
//
//   st: 2D输入坐标（任意连续值）
//   返回: 平滑噪声值，范围约 [0, 1]
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    vec2 u = f * f * (3.0 - 2.0 * f);  // Hermite 平滑

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// ----------------------------------------------------------------
// fbm —— 分形布朗运动（Fractional Brownian Motion）
// ----------------------------------------------------------------
// 算法：通过在多个尺度（倍频程）上叠加噪声来创建自然的自相似纹理。
//
// 原理（倍频程叠加）：
//   每层（octave）的特征：
//     - frequency *= 2.0  → 每层频率翻倍（细节越来越密）
//     - amplitude *= 0.5  → 每层振幅减半（贡献越来越弱）
//     - 加入时间变量 TIME → 产生流动动画效果
//
//   这种 1/f 频谱分布模仿了自然界中许多现象的统计特征
//   （如云、山脉、水面波纹等）。
//
//   共4层倍频程（i=0..3），总效果：
//   fbm = 0.5*noise(f) + 0.25*noise(2f) + 0.125*noise(4f) + 0.0625*noise(8f)
//
//   st: 2D输入坐标
//   返回: 分形噪声值，范围约 [0, 1]
float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(st * frequency + TIME * wobble_speed * 0.5);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

// ================================================================
// ██████  VERTEX 着色器 —— 顶点形变
// ================================================================
// 功能：对史莱姆网格的顶点施加正弦波动态偏移，产生果冻/液态晃动的
// 视觉效果。
//
// 【形变策略】
//   边缘因子 edge_factor = |UV.x - 0.5| * 2.0
//     → UV.x=0.5（中心）时 edge_factor=0（不变形）
//     → UV.x=0.0或1.0（边缘）时 edge_factor=1（最大形变）
//   这意味着：形变在中心为零，向边缘线性增强，产生"果冻晃动"感
//
//   Y 轴形变：sin(TIME * wobble_speed) * wobble * 20.0 * edge_factor
//     → 上下正弦晃动，幅度受 wobble 和边缘位置控制
//
//   X 轴形变：cos(TIME * wobble_speed * 0.7) * wobble * 15.0 * edge_factor
//     → 水平正弦晃动（不同频率0.7倍，不同幅度15.0），
//       使得 X/Y 晃动不同步，产生更自然的弹性感
//
//   当 enable_dynamic = false 时跳过所有形变
void vertex() {
    // 计算边缘因子：UV.x离0.5越远（越靠近左右边缘），形变越大
    float edge_factor = abs(UV.x - 0.5) * 2.0;
    if (enable_dynamic) {
        // Y轴正弦形变：上下晃动
        float wobble = sin(TIME * wobble_speed) * liquid_wobble * 20.0;
        VERTEX.y += wobble * edge_factor;
        // X轴余弦形变：水平晃动（频率×0.7与Y轴不同步，更自然）
        VERTEX.x += cos(TIME * wobble_speed * 0.7) * liquid_wobble * 15.0 * edge_factor;
    }
}

// ================================================================
// ██████  FRAGMENT 着色器 —— 像素渲染
// ================================================================
// 渲染管线分步详解：
//
// 【步骤1】噪声扰动 → 模拟玻璃内部的不均匀折射
//   使用 FBM 噪声对 UV 坐标进行微小偏移，产生"液体内部流动"效果
//
// 【步骤2】纹理采样 → 获取史莱姆形状遮罩
//   使用扰动后的 UV 采样纹理，alpha 通道 = 形状遮罩
//
// 【步骤3】菲涅尔边缘光 → 边缘比中心更亮
//   利用到中心的距离计算边缘因子，施加菲涅尔幂函数
//   模拟玻璃边缘的光线聚集效应
//
// 【步骤4】高光/镜面反射 → 产生曲面上的亮斑
//   在固定位置（右上角偏移）计算圆形高光区域
//
// 【步骤5】颜色混合 → 靠近边缘的颜色向白色偏移
//   模拟光线在玻璃边缘散射产生的"更亮更白"效果
//
// 【步骤6】透明度调整 → 中心更透明，边缘更不透明
//   模拟厚度变化：越靠近中心越薄，越透明
void fragment() {
    vec2 uv = UV;

    // ====== 步骤1：计算FBM噪声扰动 ======
    float distortion = 0.0;
    if (enable_dynamic) {
        // 使用 FBM 生成有机的流动噪声纹理
        // uv*3.0 控制噪声的细节密度
        // liquid_wobble 控制扰动强度
        distortion = fbm(uv * 3.0) * liquid_wobble;
    }

    // ====== 步骤2：扰动UV并采样纹理 ======
    // 对UV施加微小偏移（distortion*0.1），模拟液体折射
    vec2 distorted_uv = uv + vec2(distortion * 0.1, distortion * 0.1);

    vec4 tex_color = texture(TEXTURE, distorted_uv);
    float shape_mask = tex_color.a;  // alpha通道作为形状遮罩

    // 在形状完全透明（mask<0.05）的区域直接丢弃像素
    // 这确保了史莱姆之外的区域不渲染任何内容
    if (shape_mask < 0.05) {
        discard;
    }

    // ====== 步骤3：菲涅尔边缘光计算 ======
    // 计算当前像素到史莱姆中心的距离
    vec2 center = vec2(0.5);
    float dist_to_center = length(uv - center);

    // dist_to_edge: 边缘因子（边缘→1，中心→0）
    // smoothstep(0.25, 0.48, dist_to_center) 产生平滑过渡
    // 0.25以内 → 输出0（确定为中心区域）
    // 0.48以上 → 输出1（确定为边缘区域）
    // 0.25~0.48之间 → 平滑过渡
    float dist_to_edge = 1.0 - smoothstep(0.25, 0.48, dist_to_center);

    // rim_light: 菲涅尔边缘光强度
    // pow(dist_to_edge, fresnel_power) → 菲涅尔幂函数
    // fresnel_power=1 → 线性衰减（宽发光带）
    // fresnel_power=3 → 三次方衰减（窄发光带，默认）
    // fresnel_power=8 → 极窄发光带（仅最外围极亮）
    // edge_glow → 整体发光强度缩放
    float rim_light = pow(dist_to_edge, fresnel_power) * edge_glow;

    // ====== 步骤4：高光/镜面反射计算 ======
    // highlight_pos: 高光位置（右上角偏移，模拟左上光源的反射）
    vec2 highlight_pos = center + vec2(0.15, -0.15);
    float highlight_dist = length(uv - highlight_pos);

    // specular: 镜面高光强度
    // smoothstep(0.0, 0.35, highlight_dist) → 在0~0.35范围内产生圆形渐变
    // 1.0 - smoothstep(x) → 反转：中心最亮
    // pow(..., 4.0) → 四次方衰减，产生尖锐的高光点
    // highlight_intensity → 整体高光强度缩放
    float specular = pow(1.0 - smoothstep(0.0, 0.35, highlight_dist), 4.0) * highlight_intensity;

    // ====== 步骤5：颜色计算与混合 ======
    vec4 final_color = glass_color;

    // 叠加边缘发光（蓝白色调，强度×0.8）
    final_color.rgb += vec3(rim_light) * 0.8;

    // 叠加镜面高光（纯白色，强度×1.2）
    final_color.rgb += vec3(specular) * 1.2;

    // 边缘颜色向白色方向混合（模拟光线散射）
    // R通道：混合到0.9（浅红），dist_to_edge权重×0.4
    // G通道：混合到0.95（浅绿），权重×0.4
    // B通道：混合到1.0（纯蓝），权重×0.6（蓝色保留更多）
    // 这三个不同的混合目标值产生边缘偏白微蓝的色调
    final_color.r = mix(final_color.r, 0.9, dist_to_edge * 0.4);
    final_color.g = mix(final_color.g, 0.95, dist_to_edge * 0.4);
    final_color.b = mix(final_color.b, 1.0, dist_to_edge * 0.6);

    // ====== 步骤6：动态微扰动（如果启用） ======
    // 添加高频FBM噪声作为颜色微变化，模拟液体内部的不均匀性
    // uv*10.0 产生更高细节的噪声，TIME*2.0 驱动快速流动
    if (enable_dynamic) {
        final_color.rgb += fbm(uv * 10.0 + TIME * 2.0) * 0.05;
    }

    // ====== 步骤7：透明度遮罩与厚度模拟 ======
    // 基础遮罩：乘以纹理的alpha通道
    final_color.a *= shape_mask;

    // 厚度模拟：中心更透明（薄处更透光）
    // dist_to_center=0（中心）→ alpha*(1-0)=alpha（完全透明）
    // dist_to_center=1（最远）→ alpha*(1-0.6)=alpha*0.4（较不透明）
    // 这模拟了玻璃/液体的厚度效应：越厚处（中心，光线路径长）越不透明
    final_color.a *= (1.0 - dist_to_center * 0.6);

    // 输出最终颜色
    COLOR = final_color;
}