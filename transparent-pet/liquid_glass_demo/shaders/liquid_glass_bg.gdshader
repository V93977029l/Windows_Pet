shader_type canvas_item;

uniform vec2 u_resolution;
uniform float u_dpr;
uniform float u_time;

uniform float u_shadowExpand;
uniform float u_shadowFactor;
uniform vec2 u_shadowPosition;
uniform int u_bgType;
uniform sampler2D u_bgTexture;
uniform float u_bgTextureRatio;
uniform int u_bgTextureReady;

uniform sampler2D u_shapeTexture;

float chessboard(vec2 uv, float size, int mode) {
    float yBars = step(size * 2.0, mod(uv.y * 2.0, size * 4.0));
    float xBars = step(size * 2.0, mod(uv.x * 2.0, size * 4.0));
    
    if (mode == 0) {
        return yBars;
    } else if (mode == 1) {
        return xBars;
    } else {
        return abs(yBars - xBars);
    }
}

float halfColor(vec2 uv) {
    // 真正的渐变，使用 smoothstep 平滑过渡
    return smoothstep(0.35, 0.65, uv.y);
}

vec2 getCoverUV(vec2 uv, float canvasAspect, float textureAspect) {
    if (canvasAspect > textureAspect) {
        float scale = textureAspect / canvasAspect;
        uv.y = uv.y * scale + 0.5 - 0.5 * scale;
    } else {
        float scale = canvasAspect / textureAspect;
        uv.x = uv.x * scale + 0.5 - 0.5 * scale;
    }
    return uv;
}

void fragment() {
    vec2 resolution1x = u_resolution.xy / u_dpr;
    vec3 bgColor = vec3(1.0);
    float bgAlpha = 1.0;
    
    if (u_bgType <= 0) {
        bgColor = vec3(1.0 - chessboard(FRAGCOORD.xy / u_dpr, 20.0, 2) / 4.0);
    } else if (u_bgType <= 1) {
        if (UV.x < 0.5 && UV.y > 0.5) {
            bgColor = vec3(chessboard(FRAGCOORD.xy / u_dpr, 10.0, 0));
        } else if (UV.x > 0.5 && UV.y < 0.5) {
            bgColor = vec3(chessboard(FRAGCOORD.xy / u_dpr, 10.0, 1));
        } else if (UV.x < 0.5 && UV.y < 0.5) {
            bgColor = vec3(0.0);
        }
    } else if (u_bgType <= 2) {
        bgColor = vec3(halfColor(FRAGCOORD.xy / u_resolution) * 0.6 + 0.3);
    } else if (u_bgType <= 3) {
        bgAlpha = 0.0;
    } else if (u_bgType <= 11) {
        if (u_bgTextureReady != 1) {
            bgColor = vec3(1.0 - chessboard(FRAGCOORD.xy / u_dpr, 20.0, 2) / 4.0);
        } else {
            vec2 uv = getCoverUV(UV, u_resolution.x / u_resolution.y, u_bgTextureRatio);
            bgColor = texture(u_bgTexture, uv).rgb;
        }
    }
    
    float shapeValue = texture(u_shapeTexture, UV).r;
    float shadow = exp(-1.0 / u_shadowExpand * shapeValue * resolution1x.y) * 0.6 * u_shadowFactor;
    
    COLOR = vec4(bgColor - vec3(shadow), bgAlpha);
}