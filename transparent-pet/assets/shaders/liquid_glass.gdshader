shader_type canvas_item;

uniform vec4 glass_color = vec4(0.1, 0.2, 0.4, 0.4);
uniform float edge_glow = 0.7;
uniform float highlight_intensity = 0.9;
uniform float liquid_wobble = 0.2;
uniform float wobble_speed = 2.0;

void vertex() {
    float wobble = sin(TIME * wobble_speed) * liquid_wobble * 2.0;
    VERTEX.y += wobble * abs(UV.x - 0.5);
    VERTEX.x += cos(TIME * wobble_speed * 0.7) * liquid_wobble * 1.5;
}

void fragment() {
    vec2 uv = UV;
    
    vec4 tex_color = texture(TEXTURE, uv);
    float shape_mask = tex_color.a;
    
    if (shape_mask < 0.05) {
        discard;
    }
    
    float dist_to_center = length(uv - vec2(0.5));
    float dist_to_edge = 1.0 - smoothstep(0.3, 0.48, dist_to_center);
    
    float rim_light = pow(dist_to_edge, 2.0) * edge_glow;
    
    vec2 highlight_dir = normalize(vec2(0.3, -0.3));
    vec2 normal = normalize(uv - vec2(0.5));
    float dot_prod = dot(normal, highlight_dir);
    float specular = pow(max(0.0, -dot_prod), 8.0) * highlight_intensity;
    
    vec4 final_color = glass_color;
    
    final_color.rgb += vec3(rim_light) * 0.8;
    final_color.rgb += vec3(specular) * 0.9;
    
    final_color.r = mix(final_color.r, 0.8, dist_to_edge * 0.3);
    final_color.g = mix(final_color.g, 0.9, dist_to_edge * 0.3);
    final_color.b = mix(final_color.b, 1.0, dist_to_edge * 0.5);
    
    final_color.a *= shape_mask;
    final_color.a *= (1.0 - dist_to_center * 0.8);
    
    COLOR = final_color;
}
