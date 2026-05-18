shader_type canvas_item;

uniform vec4 glass_color = vec4(0.1, 0.3, 0.6, 1.0);
uniform float edge_glow = 0.8;
uniform float highlight_intensity = 1.0;
uniform float liquid_wobble = 0.3;
uniform float wobble_speed = 2.0;
uniform float fresnel_power = 3.0;
uniform bool enable_dynamic = true;

float random(vec2 st) {
    return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

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

void vertex() {
    if (enable_dynamic) {
        float wobble = sin(TIME * wobble_speed) * liquid_wobble * 2.0;
        VERTEX.y += wobble * abs(UV.x - 0.5);
        VERTEX.x += cos(TIME * wobble_speed * 0.7) * liquid_wobble * 1.5;
    }
}

void fragment() {
    vec2 uv = UV;
    
    float distortion = 0.0;
    if (enable_dynamic) {
        distortion = fbm(uv * 3.0) * liquid_wobble;
    }
    vec2 distorted_uv = uv + vec2(distortion * 0.1, distortion * 0.1);
    
    vec4 tex_color = texture(TEXTURE, distorted_uv);
    float shape_mask = tex_color.a;
    
    if (shape_mask < 0.05) {
        discard;
    }
    
    vec2 center = vec2(0.5);
    float dist_to_center = length(uv - center);
    float dist_to_edge = 1.0 - smoothstep(0.25, 0.48, dist_to_center);
    
    float rim_light = pow(dist_to_edge, fresnel_power) * edge_glow;
    
    vec2 highlight_pos = center + vec2(0.15, -0.15);
    float highlight_dist = length(uv - highlight_pos);
    float specular = pow(1.0 - smoothstep(0.0, 0.35, highlight_dist), 4.0) * highlight_intensity;
    
    vec4 final_color = glass_color;
    
    final_color.rgb += vec3(rim_light) * 0.8;
    final_color.rgb += vec3(specular) * 1.2;
    
    final_color.r = mix(final_color.r, 0.9, dist_to_edge * 0.4);
    final_color.g = mix(final_color.g, 0.95, dist_to_edge * 0.4);
    final_color.b = mix(final_color.b, 1.0, dist_to_edge * 0.6);
    
    if (enable_dynamic) {
        final_color.rgb += fbm(uv * 10.0 + TIME * 2.0) * 0.05;
    }
    
    final_color.a *= shape_mask;
    final_color.a *= (1.0 - dist_to_center * 0.6);
    
    COLOR = final_color;
}