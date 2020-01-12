#define INV_GAMMA 0.454545
#iChannel0 "file://./02/pathCode.frag"

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    //Camera setup
    vec2 uv = fragPos / iResolution.xy;
    vec3 col = vec3(0.0);

    //Time averaging previous frames
    if(iFrame > 0)
    {
        col = texture(iChannel0, uv).xyz;
        col /= float(iFrame);
    }

    //Postprocessing
    col *= 2.0;                                     // Exposure
    col = pow(col, vec3(INV_GAMMA));                // Gamma correction
    //col = mix(vec3(0.0, 0.0, 0.0), vec3(1.0), col); // Color Tweak

    fragColor = vec4(col, 1.0);
}