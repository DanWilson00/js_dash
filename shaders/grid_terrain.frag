#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;

out vec4 fragColor;

void main() {
    vec2 uv = (FlutterFragCoord().xy - 0.5 * uResolution.xy) / uResolution.y;
    
    // Simple camera movement
    float speed = 0.3;
    vec3 ro = vec3(0.0, 1.2, uTime * speed);
    vec3 rd = normalize(vec3(uv.x, uv.y - 0.15, 1.0));
    
    // Floor plane intersection
    float t = -ro.y / rd.y;
    
    vec3 col = vec3(0.0);
    
    if (t > 0.0) {
        vec3 pos = ro + t * rd;
        
        // Clean grid lines
        vec2 grid = fract(pos.xz * 1.5) - 0.5;
        float line = min(abs(grid.x), abs(grid.y));
        float intensity = smoothstep(0.04, 0.0, line) * 0.6;
        
        // Distance fading
        float fade = exp(-t * 0.2);
        
        // Clean cyan grid color
        vec3 gridColor = vec3(0.0, 0.7, 1.0);
        
        // Apply grid
        col += gridColor * intensity * fade;
        
        // Minimal floor ambient
        col += vec3(0.0, 0.05, 0.1) * fade * 0.3;
    }
    
    // Simple background gradient
    vec3 skyGradient = mix(
        vec3(0.0, 0.0, 0.02),      // Deep space
        vec3(0.0, 0.03, 0.08),     // Horizon
        smoothstep(-0.5, 0.5, uv.y)
    );
    
    col += skyGradient;
    
    // Clean vignette
    float vignette = 1.0 - smoothstep(0.0, 1.2, length(uv)) * 0.3;
    col *= vignette;
    
    // Ensure minimum brightness for visibility
    col = max(col, vec3(0.01, 0.02, 0.04));

    fragColor = vec4(col, 1.0);
}
