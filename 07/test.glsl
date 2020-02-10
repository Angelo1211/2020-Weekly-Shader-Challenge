#include "./common.glsl"

void
mainImage(out vec4 fragColor, in vec2 fragPosition)
{
    vec2 uv  = ((fragPosition) - 0.5*iResolution.xy)/iResolution.y;
    vec3 col = vec3(uv, 0.0);

    col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}