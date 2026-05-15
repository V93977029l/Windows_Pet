shader_type canvas_item;

uniform vec4 tint_color = vec4(0.9, 0.95, 1.0, 0.35);
uniform float frost_intensity = 0.5;
uniform float noise_scale = 0.3;
uniform float opacity = 0.6;

float random(vec2 st) {
    return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a)* u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 st, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(st * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

void fragment() {
    vec2 uv = UV;
    
    vec4 tex_color = texture(TEXTURE, uv);
    
    if (tex_color.a < 0.05) {
        discard;
    }
    
    float noise_val = fbm(uv * noise_scale * 50.0, 4);
    noise_val = smoothstep(0.3, 0.7, noise_val);
    
    vec3 blurred = tex_color.rgb;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 offset = vec2(float(x) * 0.005, float(y) * 0.005);
            blurred += texture(TEXTURE, uv + offset).rgb;
        }
    }
    blurred /= 9.0;
    
    vec4 frost_color = tint_color;
    frost_color.a = opacity;
    
    vec3 final_rgb = mix(blurred, frost_color.rgb, frost_intensity);
    final_rgb += noise_val * 0.08 * frost_intensity;
    
    COLOR = vec4(final_rgb, tex_color.a * opacity);
}