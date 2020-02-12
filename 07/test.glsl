#include "./common.glsl"

float
makeStar(vec2 uv, float flare)
{
    float d = length(uv);
    float star = .06/d;
    float m = star;


    float rays = max(1.0 - abs(uv.x*uv.y * 1000.0), 0.0);
    m +=rays * flare;

    uv = rotate(uv, M_PI/ 4.0);
    rays = max(1.0 - abs(uv.x*uv.y * 1000.0), 0.0);
    m +=rays*flare *0.3;

    return m;
}


void
mainImage(out vec4 fragColor, in vec2 fragPosition)
{
    vec2 uv  = ((fragPosition) - 0.5*iResolution.xy)/iResolution.y;
    uv *= 3.0;

    vec3 col = vec3(0.0);


    vec2 gv = fract(uv) - 0.5;
    col += makeStar(gv, 1.0);
    //col.rg += gv;


    //col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}