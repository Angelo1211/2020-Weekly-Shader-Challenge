#include "./common.glsl"

#define CELLS 2.0
#define AA 4

vec2
square(vec2 Z)
{
    //a^2 - b^2 + 2abi
    return vec2(Z.x* Z.x - Z.y * Z.y, 2.0*Z.x*Z.y);
}

vec3
mandelbrot(vec2 uv, const int max_steps, float zoom, vec2 offset)
{
    vec3 col = vec3(0.0);

    vec2 C = uv;
    C *= zoom;
    C += offset;
    vec2 Z  = vec2(0.0);

    for(int i = 0; i < max_steps; ++i)
    {
        Z = square(Z) + C;

        if(length(Z) > 2.0)
        {
            col += vec3(1.0, 0.0, 1.0);
            break;
        }
    }

    return col;
}

vec3
julia(vec2 uv, const int max_steps, float zoom, vec2 offset)
{
    vec3 col = vec3(0.0);

    vec2 C = offset;
    vec2 Z  = uv;

    for(int i = 0; i < max_steps; ++i)
    {
        //a^2 - b^2 + 2abi
        Z = square(Z) + C;

        if(length(Z) > 2.0)
        {
            col += vec3(1.0, 1.0, 1.0);
            break;
        }
    }

    return col;
}

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    float AR = iResolution.x / iResolution.y;
    vec3 col;
    vec3 tot = vec3(0.0);
    vec2 mouse = (iMouse.xy - 0.5*iResolution.xy) / iResolution.x;
    //mouse.y = 1.0 - mouse.y;
    //vec2 mouse = (iMouse.xy) / iResolution.xy;

    //AA for the extra niceness
    for(int i = 0; i < AA; ++i)
    for(int j = 0; j < AA; ++j)
    {
        vec2 offset = vec2(i, j) / float(AA) - 0.5;

        vec2 muv = ((fragPos + offset) - 0.5*iResolution.xy ) / iResolution.y;
        vec2 uv = ((fragPos + offset)) / iResolution.xy;

        vec2 uv2 = uv;
        uv2.x = 1.0 - uv2.x;
        uv2 *= vec2(2.6, 2.6);
        vec2 id = floor(uv2);
        uv2 = vec2(1.0 - uv2.x, uv2.y);
        vec2 juv = (fract(uv2) - 0.5);
        juv.x *= AR;

        const int max_steps = 500;
        float zoom = 2.0;
        vec2 mov = vec2(0.0);
        vec2 movement = mouse.xy;

        float inJulia = saturate(1.0 - id.y) * saturate(1.0 - id.x); 
        float inMandelbrot = 1.0 - inJulia;

        col = mandelbrot(muv, max_steps, zoom, vec2(0.0) ) * inMandelbrot;
        col += mandelbrot(juv, max_steps, zoom, vec2(0.0)) * inJulia;
        col += (length(muv - mouse.xy) < 0.02) ? vec3(1.0) : vec3(0.0);
        //col += vec3(mouse.xy, 0.0) * inJulia;
        //col += vec3(0.0, 1.0, 0.0) * inJulia;


#if 0
        float bound = 0.889;

        bool mandelTopBound = muv.x > bound;
        bool juliaTopBound = (juv.x) > bound;

        col = ( (mandelTopBound) ? vec3(0.0, 0.0, 1.0) : vec3(0.0)) * inMandelbrot;
        col += ( (juliaTopBound) ? vec3(1.0, 0.0, 0.0) : vec3(0.0)) * inJulia;
#endif

        tot += col;
    }
    tot /= float(AA*AA);

    GAMMA(tot);
    fragColor = vec4(tot, 1.0);
}