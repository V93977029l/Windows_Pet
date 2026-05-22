shader_type canvas_item;

uniform sampler2D u_prevPassTexture;
uniform vec2 u_resolution;
uniform float u_dpr;
uniform float u_blurRadius;

const int MAX_KERNEL_SIZE = 64;
uniform float u_blurWeights[MAX_KERNEL_SIZE];
uniform bool u_vertical;

void fragment() {
    vec2 texelSize = 1.0 / u_resolution * u_dpr;
    
    vec4 color = vec4(0.0);
    float totalWeight = 0.0;
    
    int kernelSize = min(int(u_blurRadius * 2.0 + 1.0), MAX_KERNEL_SIZE);
    int halfKernel = kernelSize / 2;
    
    for (int i = 0; i < kernelSize; i++) {
        int offset = i - halfKernel;
        vec2 uvOffset = u_vertical ? vec2(0.0, float(offset)) : vec2(float(offset), 0.0);
        uvOffset *= texelSize;
        
        float weight = u_blurWeights[i];
        color += texture(u_prevPassTexture, UV + uvOffset) * weight;
        totalWeight += weight;
    }
    
    if (totalWeight > 0.0) {
        color /= totalWeight;
    }
    
    COLOR = color;
}