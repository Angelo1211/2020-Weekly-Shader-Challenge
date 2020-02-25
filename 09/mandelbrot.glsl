#include "./common.glsl"

#define MAX_STEPS 50

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    //vec2 uv = (fragPos) / iResolution.xy;
    vec2 uv = ((fragPos) - 0.5*iResolution.xy) / iResolution.y;

    //uv.y = fract(uv.y*1.0);




    vec2 C = uv;
    C *= 4.1;
    C += vec2(-1.0, 0.0);
    vec2 Z  = vec2(0.0);

    for(int i = 0; i < MAX_STEPS; ++i)
    {
        //a^2 - b^2 + 2abi
        Z = vec2(Z.x* Z.x - Z.y * Z.y, 2.0*Z.x*Z.y) + C;


        if(length(Z) > 2.0)
        {
            fragColor.xyz = vec3(1.0);
            break;
        }
    }
    fragColor.w = 1.0;
}