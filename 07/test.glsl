#include "./common.glsl"

void
mainImage(out vec4 fragColor, in vec2 fragPosition)
{
    vec2 uv  = ((fragPosition) - 0.5*iResolution.xy)/iResolution.y;
    uv *= 3.0;

    vec3 col = vec3(0.0);
    float d = length(uv);
    float star = .02/d;
    col += star;


    float rays = max(1.-abs(uv.x*uv.y * 10.0), 0.0);
    col += rays;



    //col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}