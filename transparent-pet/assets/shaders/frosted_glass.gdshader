shader_type canvas_item;

uniform vec4 tint_color = vec4(0.8, 0.9, 1.0, 0.4);
uniform float frost_intensity = 0.7;
uniform float noise_scale = 0.5;
uniform float opacity = 0.6;

float random(vec2 st) {
    return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    
    float noise = random(uv * noise_scale * 100.0);
    noise = smoothstep(0.3, 0.7, noise);
    
    vec4 frost_color = tint_color;
    frost_color.a = opacity;
    
    vec4 final_color = frost_color;
    final_color.rgb += noise * 0.15;
    
    COLOR = final_color;
}
