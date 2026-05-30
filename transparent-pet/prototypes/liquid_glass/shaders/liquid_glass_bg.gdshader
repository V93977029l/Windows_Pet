shader_type canvas_item;

// ================================================================
// ██████  背景渲染着色器
// ██████
// ================================================================
// 此着色器负责渲染液态玻璃效果背后的背景图案。
// 它支持多种背景模式，用于不同的使用场景和调试目的。
//
// 【背景模式枚举（由 u_bgType 控制）】
//   u_bgType ≤ 0  → 棋盘格（默认）
//   u_bgType ≤ 1  → 四宫格模式（四象限不同图案）
//   u_bgType ≤ 2  → 垂直渐变（上半暗，下半亮）
//   u_bgType ≤ 3  → 完全透明
//   u_bgType ≤ 11 → 自定义纹理背景
//
// 【为什么要设计多种背景模式？】
//   - 棋盘格：经典的透明背景表示法，方便观察玻璃的透明度效果
//   - 渐变：测试不同亮度背景下的折射效果
//   - 透明：用于导出或叠加在其他内容之上
//   - 纹理：用户自定义图片作为背景

// ----------------------------------------------------------------
// UNIFORM 变量说明
// ----------------------------------------------------------------

// u_resolution: 渲染分辨率（像素）
uniform vec2 u_resolution;

// u_dpr: 设备像素比（高DPI缩放因子）
uniform float u_dpr;

// u_time: 时间变量（本着色器中未直接使用，预留用于未来动画效果）
uniform float u_time;

// 【阴影参数】
// u_shadowExpand: 阴影扩散范围
//   值越大，阴影越扩散、越大；值越小，阴影越紧凑
uniform float u_shadowExpand;

// u_shadowFactor: 阴影强度因子
//   0.0 = 无阴影，1.0 = 满强度阴影
uniform float u_shadowFactor;

// u_shadowPosition: 阴影偏移位置（通常与光源方向相反）
//   例如 vec2(20, 30) 表示阴影向右下方偏移
uniform vec2 u_shadowPosition;

// 【背景模式控制】
// u_bgType: 背景类型选择
//   见顶部枚举说明
uniform int u_bgType;

// u_bgTexture: 自定义背景纹理（当 u_bgType≤11 时使用）
uniform sampler2D u_bgTexture;

// u_bgTextureRatio: 背景纹理的宽高比（宽/高）
//   用于 Cover 模式缩放（类似 CSS 的 object-fit: cover）
uniform float u_bgTextureRatio;

// u_bgTextureReady: 背景纹理是否已加载就绪
//   0 = 未就绪（回退到棋盘格）
//   1 = 已就绪（正常显示纹理）
uniform int u_bgTextureReady;

// u_shapeTexture: 史莱姆形状遮罩纹理
//   R 通道包含 SDF 形状信息，用于计算阴影
uniform sampler2D u_shapeTexture;

// ================================================================
// chessboard —— 棋盘格图案生成
// ================================================================
// 数学原理：利用 mod（取模）运算将 UV 空间分割为重复的方格，
// 再通过 step 函数在两种颜色之间切换。
//
// 算法步骤：
//   1. mod(uv.y * 2.0, size * 4.0) → 将 y 坐标映射到 [0, 4*size) 周期
//      乘以2.0是因为标准格子是 size*2 的周期
//   2. step(size*2.0, ...) → 周期过半后切换（产生黑白交替）
//
// 模式说明：
//   mode=0 (yBars):    生成水平条纹
//                      周期: size*2 → 每格 height=size*2
//                      示例: ██░░██░░  (横向条纹)
//
//   mode=1 (xBars):    生成竖直条纹
//                      周期: size*2 → 每格 width=size*2
//                      示例: █░█░ (纵向条纹)
//
//   mode=2 (棋盘格):   生成标准棋盘格
//                      abs(yBars - xBars) 当两者相同时=0（黑）
//                      当两者不同时=1（白），产生交错效果
//                      示例: █░█░
//                             ░█░█
//
//   uv:   纹理坐标（通常以像素为单位传入 FRAGCOORD/dpr）
//   size: 每个格子的尺寸（像素）
//   mode: 0=水平条, 1=竖直条, 2=棋盘格
//   返回: 0.0（黑）或 1.0（白）
float chessboard(vec2 uv, float size, int mode) {
    // 计算水平条纹：y坐标的取模和阈值判断
    float yBars = step(size * 2.0, mod(uv.y * 2.0, size * 4.0));
    // 计算竖直条纹：x坐标的取模和阈值判断
    float xBars = step(size * 2.0, mod(uv.x * 2.0, size * 4.0));

    if (mode == 0) {
        // 仅水平条纹
        return yBars;
    } else if (mode == 1) {
        // 仅竖直条纹
        return xBars;
    } else {
        // 棋盘格 = 水平 ⊕ 竖直（异或效果）
        // 当水平和竖直不同时=1（白），相同时=0（黑）
        return abs(yBars - xBars);
    }
}

// ================================================================
// halfColor —— 垂直渐变函数
// ================================================================
// 功能：从顶部暗到下部亮产生平滑的垂直渐变过渡。
//
// 使用 smoothstep(0.35, 0.65, uv.y) 在 UV.y 的 35%~65% 区间
// 产生平滑渐变，避免硬边界。
//
//   uv: 纹理坐标（范围 [0,1]）
//   返回: 0.0（顶暗）~ 1.0（底亮）
float halfColor(vec2 uv) {
    // 真正的渐变，使用 smoothstep 平滑过渡
    return smoothstep(0.35, 0.65, uv.y);
}

// ================================================================
// getCoverUV —— Cover 模式 UV 变换
// ================================================================
// 功能：模拟 CSS 的 object-fit: cover 行为。
// 将任意宽高比的纹理缩放并裁剪以填充目标画布，同时保持原始比例。
//
// 算法原理：
//   - 当画布比纹理更宽（canvasAspect > textureAspect）：
//     纹理在水平方向足够宽，需要在垂直方向压缩（scale<1）
//     UV.y 缩放并居中
//   - 当画布比纹理更窄（canvasAspect < textureAspect）：
//     纹理在垂直方向足够高，需要在水平方向压缩（scale<1）
//     UV.x 缩放并居中
//
// 这种变换确保背景纹理始终铺满整个区域，不留黑边。
//
//   uv:             原始 UV 坐标 [0,1]
//   canvasAspect:   画布宽高比（宽/高）
//   textureAspect:  纹理宽高比（宽/高）
//   返回:            变换后的 UV 坐标
vec2 getCoverUV(vec2 uv, float canvasAspect, float textureAspect) {
    if (canvasAspect > textureAspect) {
        // 画布更宽 → 纹理需要上下裁剪
        float scale = textureAspect / canvasAspect;
        uv.y = uv.y * scale + 0.5 - 0.5 * scale;
    } else {
        // 画布更高 → 纹理需要左右裁剪
        float scale = canvasAspect / textureAspect;
        uv.x = uv.x * scale + 0.5 - 0.5 * scale;
    }
    return uv;
}

// ================================================================
// ██████  FRAGMENT 着色器 —— 多模式背景 + 阴影合成
// ================================================================
void fragment() {
    // ====== 计算1x分辨率的画布尺寸（用于像素级计算） ======
    vec2 resolution1x = u_resolution.xy / u_dpr;

    // ====== 初始化背景颜色和透明度 ======
    vec3 bgColor = vec3(1.0);  // 默认白色
    float bgAlpha = 1.0;        // 默认不透明

    // ====== 背景模式分支选择 ======
    if (u_bgType <= 0) {
        // 【模式0：标准棋盘格】
        // 使用像素坐标（FRAGCOORD/dpr）生成棋盘格，确保不受缩放影响
        // 每个格子 20 像素
        // 公式：1.0 - chessboard/4.0 → 棋盘格的黑格为灰(0.75)，白格为白(1.0)
        bgColor = vec3(1.0 - chessboard(FRAGCOORD.xy / u_dpr, 20.0, 2) / 4.0);
    } else if (u_bgType <= 1) {
        // 【模式1：四宫格测试模式】
        // 将画布分为四个象限，每个象限显示不同的图案：
        //   左上 (UV.x<0.5, UV.y>0.5)：水平条纹（mode=0）
        //   右下 (UV.x>0.5, UV.y<0.5)：竖直条纹（mode=1）
        //   左下 (UV.x<0.5, UV.y<0.5)：纯黑色
        //   右上 (UV.x>0.5, UV.y>0.5)：默认白色
        // 这种模式用于测试和演示不同的棋盘格变体
        if (UV.x < 0.5 && UV.y > 0.5) {
            bgColor = vec3(chessboard(FRAGCOORD.xy / u_dpr, 10.0, 0));
        } else if (UV.x > 0.5 && UV.y < 0.5) {
            bgColor = vec3(chessboard(FRAGCOORD.xy / u_dpr, 10.0, 1));
        } else if (UV.x < 0.5 && UV.y < 0.5) {
            bgColor = vec3(0.0);
        }
    } else if (u_bgType <= 2) {
        // 【模式2：垂直渐变】
        // halfColor 在顶部输出暗色（~0），底部输出亮色（~1）
        // *0.6 + 0.3 将范围映射到 [0.3, 0.9]（柔和的浅灰到深灰渐变）
        bgColor = vec3(halfColor(FRAGCOORD.xy / u_resolution) * 0.6 + 0.3);
    } else if (u_bgType <= 3) {
        // 【模式3：完全透明】
        // 设置 alpha=0，背景不可见
        // 适用于将史莱姆叠加在其他UI或图像之上的场景
        bgAlpha = 0.0;
    } else if (u_bgType <= 11) {
        // 【模式4-11：自定义纹理背景】
        if (u_bgTextureReady != 1) {
            // 纹理未就绪 → 回退到棋盘格（与模式0相同）
            bgColor = vec3(1.0 - chessboard(FRAGCOORD.xy / u_dpr, 20.0, 2) / 4.0);
        } else {
            // 纹理已就绪 → 使用 Cover 模式采样纹理
            vec2 uv = getCoverUV(UV, u_resolution.x / u_resolution.y, u_bgTextureRatio);
            bgColor = texture(u_bgTexture, uv).rgb;
        }
    }

    // ====== 阴影计算 ======
    // 从形状纹理的R通道读取形状SDF值
    // 使用指数衰减函数创建软阴影效果：
    //
    //   exp(-(1/u_shadowExpand) * shapeValue * resolution1x.y)
    //
    // 阴影原理（基于 SDF 的软阴影）：
    //   shapeValue 越大（形状越"实"），阴影越浓
    //   shapeValue 越小（越接近边缘），阴影越淡
    //   指数函数确保阴影从形状向外平滑衰减
    //
    // 最终阴影 = 衰减值 * 0.6 * u_shadowFactor
    //   0.6 是硬编码的阴影基础强度
    float shapeValue = texture(u_shapeTexture, UV).r;
    float shadow = exp(-1.0 / u_shadowExpand * shapeValue * resolution1x.y) * 0.6 * u_shadowFactor;

    // ====== 合成最终像素 ======
    // 从背景颜色中减去阴影 → 阴影区域变暗
    COLOR = vec4(bgColor - vec3(shadow), bgAlpha);
}