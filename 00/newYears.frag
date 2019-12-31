#define INV_GAMMA 0.454545
#define AA 2

#define CIRCLE 1.0f
#define CIRCLE2 2.0f

#define ONETOZERO(num) (num + 1.0f) / 2.0f

/*Game Plan:
    [ ] Clock
    [ ] Hand strikes twelve
    [ ] Fireworks from behind the clock
    [ ] Star background
    [ ] Buildings w/ lights
*/

float
sdCircle(vec2 pos, float radius)
{
    return length(pos) - radius;
}

float
Map(vec2 uv) 
{
    float res = -1.0;

    //If you're inside the sdf, return it's ID
    res = (sdCircle(uv - vec2(0.1, 0.1), 0.35) <= 0.0) ? CIRCLE2 : res;  
    res = (sdCircle(uv - vec2(0.0, 0.0), 0.35) <= 0.0) ? CIRCLE : res;  



    return res;
}

vec3
Shading(float id)
{
    vec3 col;
    //Default case
    if (id  == -1.0f)
    {
        col = vec3(1.0);
    }

    if (id == CIRCLE)
    {
        col = vec3(1.0 * ONETOZERO(sin(iTime)), 0.0, ONETOZERO(sin(2.0*iTime)));
    }

    if (id == CIRCLE2)
    {
        col = vec3(0.0, 1.0, 0.0);
    }

    return col;
}

vec3
Render(vec2 uv)
{
    //Geometry
    float id = Map(uv);

    //Shading
    vec3 col = Shading(id);

    //Post processing

    return col;
}

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    vec3 tot;

    //Supersampling AA
#if AA > 1
    for(int i = 0; i < AA; ++i)
    for(int j = 0; j < AA; ++j)
    {
        vec2 offset = vec2(i, j) / float(AA) - 0.5;
        vec2 uv = ((fragPos + offset) - 0.5*iResolution.xy) / iResolution.y;
#else
        vec2 uv = ((fragPos) - 0.5*iResolution.xy) / iResolution.y;
#endif

        //Rendering
        vec3 col = Render(uv);

        //Gamma correction
        col = pow(col, vec3(INV_GAMMA));
        tot += col;
#if AA > 1
    }
    tot /= float(AA*AA);
#endif
    fragColor = vec4(tot, 1.0);
}