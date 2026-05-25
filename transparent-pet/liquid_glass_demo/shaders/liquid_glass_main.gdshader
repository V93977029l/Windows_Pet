shader_type canvas_item;

const float N_R = 0.98;
const float N_G = 1.0;
const float N_B = 1.02;

const int MAX_ITEMS = 3;

float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

float superellipseCornerSDF(vec2 p, float r, float n) {
    p = abs(p);
    float v = pow(pow(p.x, n) + pow(p.y, n), 1.0 / n);
    return v - r;
}

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

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

vec2 bezier3(vec2 a, vec2 b, vec2 c, vec2 d, float t) {
    float u = 1.0 - t;
    return u*u*u * a + 3.0*u*u*t * b + 3.0*u*t*t * c + t*t*t * d;
}

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

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

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

float sdSlime(vec2 p) {
    // SVG 右上 → q空间: P0(0,-0.231) P1(0.25,-0.231) P2(0.4,-0.055) P3(0.4,0.11)
    // SVG 右下 → q空间: P0(0.4,0.11) P1(0.4,0.22) P2(0.325,0.275) P3(0.25,0.275)
    // SVG 底部直线: (-0.25, 0.275) → (0.25, 0.275)
    // SVG 顶部 y=-0.231

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

uniform sampler2D u_blurredBg;
uniform sampler2D u_bg;
uniform vec2 u_resolution;
uniform float u_dpr;
uniform vec2 u_mouse;
uniform vec2 u_mouseSpring;
uniform float u_mergeRate;

uniform vec2 u_itemPositions[MAX_ITEMS];
uniform float u_itemWidths[MAX_ITEMS];
uniform float u_itemHeights[MAX_ITEMS];
uniform float u_itemRadii[MAX_ITEMS];
uniform float u_itemRoundness[MAX_ITEMS];
uniform float u_itemShapeTypes[MAX_ITEMS];
uniform float u_itemEnabled[MAX_ITEMS];
uniform float u_itemScales[MAX_ITEMS];

uniform vec4 u_tint;
uniform float u_refThickness;
uniform float u_refFactor;
uniform float u_refDispersion;
uniform float u_refFresnelRange;
uniform float u_refFresnelHardness;
uniform float u_refFresnelFactor;
uniform float u_glareRange;
uniform float u_glareConvergence;
uniform float u_glareOppositeFactor;
uniform float u_glareFactor;
uniform float u_glareHardness;
uniform float u_glareAngle;
uniform int u_blurEdge;
uniform int STEP;

float getItemSDF(int index, vec2 p) {
    if (u_itemEnabled[index] < 0.5) {
        return 1.0;
    }
    
    vec2 position = u_itemPositions[index];
    float width = u_itemWidths[index];
    float height = u_itemHeights[index];
    float radius = u_itemRadii[index];
    float roundness = u_itemRoundness[index];
    float shapeType = u_itemShapeTypes[index];
    float scale = u_itemScales[index];
    
    vec2 pn = (p - position) / u_resolution.y;
    
    if (shapeType < 0.5) {
        return sdCircle(pn, radius * u_dpr * scale / u_resolution.y);
    } else if (shapeType < 1.5) {
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
        float slimeD = sdSlime(pn * u_resolution.y / (width * u_dpr * scale));
        return slimeD * width * u_dpr * scale / u_resolution.y;
    }
}

float mainSDF(vec2 p) {
    float result = 1.0;
    
    for (int i = 0; i < MAX_ITEMS; i++) {
        float d = getItemSDF(i, p);
        result = smin(result, d, u_mergeRate);
    }
    
    return result;
}

vec2 getNormal(vec2 p) {
    vec2 h = vec2(max(abs(dFdx(p.x)), 0.0001), max(abs(dFdy(p.y)), 0.0001));
    
    vec2 grad = vec2(
        mainSDF(p + vec2(h.x, 0.0)) - mainSDF(p - vec2(h.x, 0.0)),
        mainSDF(p + vec2(0.0, h.y)) - mainSDF(p - vec2(0.0, h.y))
    ) / (2.0 * h);
    
    return grad * 1.414213562 * 1000.0;
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

const vec3 D65_WHITE = vec3(0.95045592705, 1.0, 1.08905775076);
const mat3 RGB_TO_XYZ_M = mat3(
    vec3(0.4124, 0.2126, 0.0193),
    vec3(0.3576, 0.7152, 0.1192),
    vec3(0.1805, 0.0722, 0.9505)
);
const mat3 XYZ_TO_RGB_M = mat3(
    vec3(3.2406255, -0.9689307, 0.0557101),
    vec3(-1.537208, 1.8757561, -0.2040211),
    vec3(-0.4986286, 0.0415175, 1.0569959)
);

float UNCOMPAND_SRGB(float a) {
    return a > 0.04045 ? pow((a + 0.055) / 1.055, 2.4) : a / 12.92;
}

float COMPAND_RGB(float a) {
    return a <= 0.0031308 ? 12.92 * a : 1.055 * pow(a, 0.41666666666) - 0.055;
}

vec3 SRGB_TO_RGB(vec3 srgb) {
    return vec3(UNCOMPAND_SRGB(srgb.x), UNCOMPAND_SRGB(srgb.y), UNCOMPAND_SRGB(srgb.z));
}

vec3 RGB_TO_SRGB(vec3 rgb) {
    return vec3(COMPAND_RGB(rgb.x), COMPAND_RGB(rgb.y), COMPAND_RGB(rgb.z));
}

vec3 RGB_TO_XYZ(vec3 rgb) {
    return rgb * RGB_TO_XYZ_M;
}

vec3 XYZ_TO_RGB(vec3 xyz) {
    return xyz * XYZ_TO_RGB_M;
}

float XYZ_TO_LAB_F(float x) {
    return x > 0.00885645167 ? pow(x, 0.333333333) : 7.78703703704 * x + 0.13793103448;
}

float LAB_TO_XYZ_F(float x) {
    return x > 0.206897 ? x * x * x : 0.12841854934 * (x - 0.137931034);
}

vec3 XYZ_TO_LAB(vec3 xyz) {
    vec3 xyz_scaled = xyz / D65_WHITE;
    xyz_scaled = vec3(XYZ_TO_LAB_F(xyz_scaled.x), XYZ_TO_LAB_F(xyz_scaled.y), XYZ_TO_LAB_F(xyz_scaled.z));
    return vec3(116.0 * xyz_scaled.y - 16.0, 500.0 * (xyz_scaled.x - xyz_scaled.y), 200.0 * (xyz_scaled.y - xyz_scaled.z));
}

vec3 LAB_TO_XYZ(vec3 Lab) {
    float w = (Lab.x + 16.0) / 116.0;
    return D65_WHITE * vec3(LAB_TO_XYZ_F(w + Lab.y / 500.0), LAB_TO_XYZ_F(w), LAB_TO_XYZ_F(w - Lab.z / 200.0));
}

vec3 SRGB_TO_LAB(vec3 srgb) {
    return XYZ_TO_LAB(RGB_TO_XYZ(SRGB_TO_RGB(srgb)));
}

vec3 LAB_TO_SRGB(vec3 lab) {
    return RGB_TO_SRGB(XYZ_TO_RGB(LAB_TO_XYZ(lab)));
}

vec3 LAB_TO_LCH(vec3 Lab) {
    return vec3(Lab.x, sqrt(dot(Lab.yz, Lab.yz)), atan(Lab.z, Lab.y) * 57.2957795131);
}

vec3 LCH_TO_LAB(vec3 LCh) {
    return vec3(LCh.x, LCh.y * cos(LCh.z * 0.01745329251), LCh.y * sin(LCh.z * 0.01745329251));
}

vec3 LCH_TO_SRGB(vec3 lch) {
    return LAB_TO_SRGB(LCH_TO_LAB(lch));
}

float vec2ToAngle(vec2 v) {
    float angle = atan(v.y, v.x);
    return angle < 0.0 ? angle + 2.0 * PI : angle;
}

vec4 getTextureDispersion(sampler2D tex1, sampler2D tex2, float mixRate, vec2 offset, float factor, vec2 uv) {
    float bgR = texture(tex1, uv + offset * (1.0 - (N_R - 1.0) * factor)).r;
    float bgG = texture(tex1, uv + offset * (1.0 - (N_G - 1.0) * factor)).g;
    float bgB = texture(tex1, uv + offset * (1.0 - (N_B - 1.0) * factor)).b;
    
    float blurR = texture(tex2, uv + offset * (1.0 - (N_R - 1.0) * factor)).r;
    float blurG = texture(tex2, uv + offset * (1.0 - (N_G - 1.0) * factor)).g;
    float blurB = texture(tex2, uv + offset * (1.0 - (N_B - 1.0) * factor)).b;
    
    return vec4(mix(bgR, blurR, mixRate), mix(bgG, blurG, mixRate), mix(bgB, blurB, mixRate), 1.0);
}

void fragment() {
    vec2 resolution1x = u_resolution.xy / u_dpr;
    float merged = mainSDF(FRAGCOORD.xy);
    
    vec4 outColor;
    
    if (STEP <= 0) {
        float px = 2.0 / u_resolution.y;
        vec3 col = merged > 0.0 ? vec3(1.0) * merged : vec3(1.0) * -merged * 2.0;
        col *= 3.0;
        col = mix(col, vec3(1.0), 1.0 - smoothstep(0.5 / resolution1x.y - px, 0.5 / resolution1x.y + px, abs(merged)));
        outColor = vec4(col, 1.0);
    } else if (STEP <= 1) {
        float px = 2.0 / u_resolution.y;
        vec3 col = merged > 0.0 ? vec3(0.9, 0.6, 0.3) : vec3(0.65, 0.85, 1.0);
        col *= 1.0 - exp(-0.03 * abs(merged) * resolution1x.y);
        col *= 0.6 + 0.4 * smoothstep(-0.5, 0.5, cos(0.25 * abs(merged) * resolution1x.y * 2.0));
        col = mix(col, vec3(1.0), 1.0 - smoothstep(1.5 / resolution1x.y - px, 1.5 / resolution1x.y + px, abs(merged)));
        outColor = vec4(col, 1.0);
    } else if (STEP <= 2) {
        if (merged < 0.0) {
            vec2 normal = getNormal(FRAGCOORD.xy);
            float angle = atan(normal.y, normal.x);
            float hue = (angle < 0.0 ? angle + 2.0 * PI : angle) / (2.0 * PI);
            vec3 normalColor = hsv2rgb(vec3(hue, 1.0, 1.0));
            outColor = vec4(normalColor, length(normal));
        } else {
            outColor = vec4(vec3(0.8), 0.0);
        }
    } else if (STEP <= 9) {
        if (merged < 0.005) {
            float nmerged = -merged * resolution1x.y;
            
            float x_R_ratio = 1.0 - nmerged / u_refThickness;
            float thetaI = asin(pow(x_R_ratio, 2.0));
            float sinThetaT = (1.0 / u_refFactor) * sin(thetaI);
            
            float edgeFactor = 0.0;
            if (sinThetaT >= -1.0 && sinThetaT <= 1.0 && nmerged < u_refThickness) {
                float thetaT = asin(sinThetaT);
                edgeFactor = -tan(thetaT - thetaI);
            }
            
            if (edgeFactor <= 0.0) {
                outColor = texture(u_blurredBg, UV);
                outColor = mix(outColor, vec4(u_tint.rgb, 1.0), u_tint.a * 0.8);
            } else {
                float edgeH = nmerged / u_refThickness;
                vec2 normal = getNormal(FRAGCOORD.xy);
                
                vec4 blurredPixel = getTextureDispersion(
                    u_bg,
                    u_blurredBg,
                    u_blurEdge > 0 ? 1.0 : edgeH,
                    -normal * edgeFactor * 0.05 * u_dpr * vec2(u_resolution.y / (resolution1x.x * u_dpr), 1.0),
                    u_refDispersion,
                    UV
                );
                
                outColor = mix(blurredPixel, vec4(u_tint.rgb, 1.0), u_tint.a * 0.8);
                
                float fresnelFactor = clamp(
                    pow(1.0 + merged * resolution1x.y / 1500.0 * pow(500.0 / u_refFresnelRange, 2.0) + u_refFresnelHardness, 5.0),
                    0.0, 1.0
                );
                
                vec3 fresnelTintLCH = SRGB_TO_LAB(mix(vec3(1.0), u_tint.rgb, u_tint.a * 0.5));
                fresnelTintLCH.x += 20.0 * fresnelFactor * u_refFresnelFactor;
                fresnelTintLCH.x = clamp(fresnelTintLCH.x, 0.0, 100.0);
                outColor = mix(outColor, vec4(LCH_TO_SRGB(fresnelTintLCH), 1.0), fresnelFactor * u_refFresnelFactor * 0.7 * length(normal));
                
                float glareGeoFactor = clamp(
                    pow(1.0 + merged * resolution1x.y / 1500.0 * pow(500.0 / u_glareRange, 2.0) + u_glareHardness, 5.0),
                    0.0, 1.0
                );
                
                float glareAngleRad = (vec2ToAngle(normalize(normal)) - PI / 4.0 + u_glareAngle) * 2.0;
                int glareFarside = 0;
                if ((glareAngleRad > PI * (2.0 - 0.5) && glareAngleRad < PI * (4.0 - 0.5)) || glareAngleRad < PI * (0.0 - 0.5)) {
                    glareFarside = 1;
                }
                
                float glareAngleFactor = (0.5 + sin(glareAngleRad) * 0.5) * (glareFarside == 1 ? 1.2 * u_glareOppositeFactor : 1.2) * u_glareFactor;
                glareAngleFactor = clamp(pow(glareAngleFactor, 0.1 + u_glareConvergence * 2.0), 0.0, 1.0);
                
                vec3 glareTintLCH = SRGB_TO_LAB(mix(blurredPixel.rgb, u_tint.rgb, u_tint.a * 0.5));
                glareTintLCH.x += 150.0 * glareAngleFactor * glareGeoFactor;
                glareTintLCH.y += 30.0 * glareAngleFactor * glareGeoFactor;
                glareTintLCH.x = clamp(glareTintLCH.x, 0.0, 120.0);
                
                outColor = mix(outColor, vec4(LCH_TO_SRGB(glareTintLCH), 1.0), glareAngleFactor * glareGeoFactor * length(normal));
            }
        } else {
            outColor = texture(u_bg, UV);
        }
    
        float dx = dFdx(merged);
        float dy = dFdy(merged);
        float aaWidth = sqrt(dx * dx + dy * dy) * 2.0;
        outColor = mix(outColor, texture(u_bg, UV), smoothstep(-aaWidth, aaWidth, merged));
    }
    
    COLOR = outColor;
}