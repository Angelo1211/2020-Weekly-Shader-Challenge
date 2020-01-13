#iChannel0 "file://./03/3pathSum.frag"

#define INV_GAMMA 0.45454   
void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    vec3 col;
    vec2 screen = fragPos / iResolution.xy;

    //"Integrating prev frame results"
    if (iFrame > 0)
    {
        col = texture(iChannel0, screen).xyz; 
        col /= float(iFrame);
    }

    //Post processing
    col = pow(col, vec3(INV_GAMMA)); //Gamma correction
    fragColor = vec4(col,1.0); 
}