#include "./common.glsl"


void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    UV(fragCoord);

    //Camera
    float nearp = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0);
    vec3 ro = ta + vec3(0.0, 0.0, -10.0);
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearp));
    
    vec3 col = vec3(rd);

    float freq = 10.0;
    /*
        Noise testing
        col = vec3(hash12(uv * freq));
        col = vec3(bilinearNoiseD(uv * freq).x);
    */
        col = vec3(terrainNoise(uv, 8, 1.0, 1.0 ));


    GAMMA(col);
    OUTPUT(col);
}