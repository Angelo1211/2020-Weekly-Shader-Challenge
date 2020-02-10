#iChannel0 "file://./06/id1_path.frag"
#include "./common.glsl"

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    vec2 uv = (fragPos) /iResolution.xy;

    vec3 col = vec3(0.0);
    if(iFrame > 0)
    {
        col = texture(iChannel0, uv).xyz;
        col /= float(iFrame);
    }

    col *= 2.5;// Exposure
    col = pow(col, vec3(INV_GAMMA)); //Gamma correction
    fragColor = vec4(col, 1.0);
}   