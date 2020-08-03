#include "./common.glsl"

// Practice 0 : 02/08/20

// Bilinear filter with derivatives Iq style
vec3
bilinearNoiseD(vec2 uv)
{
    vec2 id = floor(uv);
    vec2 fr = fract(uv);

    // Cubic interpolation
    vec2 interp = fr * fr * (3.0 - 2.0*fr);

    // Cubic interp derivative
    vec2 interp_D = 6.0 * fr * (1.0 - fr);

    // Bottom
    float bl = hash12(id + vec2(0.0, 0.0));
    float br = hash12(id + vec2(1.0, 0.0));
    float b  = mix(bl, br, interp.x); 

    // Top
    float tl = hash12(id + vec2(0.0, 1.0));
    float tr = hash12(id + vec2(1.0, 1.0));
    float t  = mix(tl, tr, interp.x); 

    // Filtered noise result
    float noise = mix(b, t, interp.y);

    //checkout pdf week 14 for where this comes from
    vec2 dNoise = interp_D * (vec2(-bl + br, -bl + tl) + (bl - br - tl + tr) * interp.yx  );
    return vec3(noise, dNoise);
}

void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    UV(fragCoord);

    // Camera setup
    float nearp = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0); 
    vec3 ro = ta + vec3(0.0, 0.0, -10.0);
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearp));

    //Noise test setup
    vec3 col = vec3(bilinearNoiseD(uv*10.0));

    GAMMA(col);
    fragColor = vec4(col, 1.0);
}