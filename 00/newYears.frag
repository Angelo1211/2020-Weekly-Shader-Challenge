#define INV_GAMMA 0.454545
#define AA 2

#define CLOCK 1.0f
#define CLOCK_RADIUS 0.35f

#define ONETOZERO(num) (num + 1.0f) / 2.0f

/*Game Plan:
    -Todo
    [ ] Hand strikes twelve
    [ ] Fireworks from behind the clock

    -In progress
    [ ] Clock Face
        - [x] Draw a 2D circle
        - [ ] Mark the 12 hours 
        - [ ] Clock hands

    -Done

    -Nice to haves
    [ ] Draw Roman Numerals
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
    res = (sdCircle(uv - vec2(0.0, 0.0), CLOCK_RADIUS) <= 0.0) ? CLOCK : res;  


    return res;
}

vec3
Shading(vec2 uv, float id)
{
    vec3 col;
    //Default case
    if (id  == -1.0f)
    {
        col = vec3(1.0);
    }

    if (id == CLOCK)
    {
        col = vec3(1.0 * ONETOZERO(sin(3.33*iTime)), 1.0 * ONETOZERO(sin(0.5*iTime-0.2)), ONETOZERO(sin(2.0*iTime - 0.5)));

        float r = length(uv);
        float a = atan(uv.y, uv.x);
        //r *= cos(a*12.0);
        bool inRadius = r > 0.3 && r < 0.35;
        bool inAngle =  a > 0.0 && a < 0.1;
        if( inAngle && inRadius )
        {
            col = vec3(0.0, 0.0, 0.0);
        }

        //Divide clock into pizza slices
        //float r = cos(atan(uv.y, uv.x)*12.0);
        //col *= smoothstep(r+0.01, r, length(uv));

        //float r = cos(atan(uv.y, uv.x)*12.0);
        //col *= smoothstep(r, r+0.01, (uv.y));

        //vec2 q = floor(uv*12.0);
        //float r = mod(q.x+q.y, 2.0);
        //col *= r;

        //float r = 0.2 + 0.1*cos(atan(uv.y, uv.x)*12.0);
        //col *= smoothstep(r,r+0.01, length(uv));

        if (abs(uv.x- 0.24) < 0.02 && abs(uv.y) < 0.02)
        {
        //    col = vec3(0.0);
        }
    }

    return col;
}

vec3
Render(vec2 uv)
{
    //Geometry
    float id = Map(uv);

    //Shading
    vec3 col = Shading(uv,id);

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