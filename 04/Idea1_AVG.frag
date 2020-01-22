#iChannel0 "file://./04/pathTracing.frag"

#define INV_GAMMA 0.4545454

void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 col = vec3(0.0);
    if(iFrame > 0)
    {
        col = texture(iChannel0, uv).xyz;
        col /= float(iFrame);
    }

    col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);    
}


/*
    float u = hash( 78.233 + seed);
    float v = hash( 10.873 + seed);

    float a = 6.2831853 * v;
    u = 2.0*u - 1.0;
    return normalize( n + vec3(sqrt(1.0-u*u) * vec2(cos(a), sin(a)), u) );   
*/