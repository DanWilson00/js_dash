#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;

out vec4 fragColor;

// 3D rotation function
mat2 rot(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

void main() {
    vec2 uv = (FlutterFragCoord().xy - 0.5 * uResolution.xy) / uResolution.y;
    
    // Camera movement
    float speed = 0.5;
    vec3 ro = vec3(0.0, 1.0, uTime * speed); // Ray origin
    vec3 rd = normalize(vec3(uv.x, uv.y - 0.2, 1.0)); // Ray direction
    
    // Floor plane
    float t = -ro.y / rd.y;
    
    vec3 col = vec3(0.0);
    
    if (t > 0.0) {
        vec3 pos = ro + t * rd;
        
        // Grid effect
        vec2 grid = fract(pos.xz * 2.0) - 0.5;
        float line = min(abs(grid.x), abs(grid.y));
        float intensity = smoothstep(0.05, 0.0, line);
        
        // Distance fading
        float fade = exp(-t * 0.2);
        
        // Color gradient for the grid
        vec3 gridColor = mix(vec3(0.0, 0.8, 1.0), vec3(1.0, 0.0, 0.5), sin(pos.z * 0.1) * 0.5 + 0.5);
        
        col += gridColor * intensity * fade;
        
        // Add a subtle glow to the floor
        col += vec3(0.0, 0.1, 0.2) * fade * 0.5;
    }
    
    // Background gradient (sky)
    vec3 skyCol = mix(vec3(0.0, 0.0, 0.05), vec3(0.0, 0.02, 0.1), uv.y + 0.5);
    col += skyCol;
    
    // Vignette
    float vig = 1.0 - length(uv) * 0.5;
    col *= vig;

    fragColor = vec4(col, 1.0);
}
