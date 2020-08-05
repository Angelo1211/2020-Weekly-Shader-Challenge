#include "./common.glsl"

// Practice 0 : 02/08/20


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