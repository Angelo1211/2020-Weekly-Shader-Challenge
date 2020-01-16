#iChannel0 "file://./03/pathTracing.frag"

#define INV_GAMMA 0.454545
/*
    p = fract(p * 0.011);
    p *= p + 7.5;
    p *= p + p; 
    return fract(p);
*/
void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    vec3 col;
    vec2 screen = fragPos / iResolution.xy;

    //Simple montecarlo integration
    if(iFrame > 0)
    {
        col = texture(iChannel0, screen).xyz;
        col /= float(iFrame);
    } 

    //Post processing
    col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}