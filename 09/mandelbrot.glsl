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
            col += vec3(1.0, 0.0, 0.0);
            break;
        }
    }

    return col;
}

vec3
julia(vec2 uv, const int max_steps, float zoom, vec2 offset)
{
    vec3 col = vec3(0.0);

    vec2 C = offset * zoom;
    vec2 Z  = uv ;

    for(int i = 0; i < max_steps; ++i)
    {
        //a^2 - b^2 + 2abi
        Z = square(Z) + C;

        if(length(Z) > 2.0)
        {
            col += vec3(1.0, 0.0, 0.0);
            break;
        }
    }

    return col;
}

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    vec3 tot = vec3(0.0);
    vec2 mouse = iMouse.xy / iResolution.xy;
    mouse.x *= CELLS;

    //AA for the extra niceness
    for(int i = 0; i < AA; ++i)
    for(int j = 0; j < AA; ++j)
    {
        vec2 offset = vec2(i, j) / float(AA) - 0.5;
        vec2 uv2 = ((fragPos + offset) - 0.5*iResolution.xy ) / iResolution.y;
        vec2 uv = ((fragPos + offset)) / iResolution.xy;
        //float id = floor(uv.x*CELLS);

        uv.x -= 1.00;
        vec2 id = floor(uv* 2.5);
        vec2 nUV = fract(uv * 2.5) - 0.5;

        const int max_steps = 50;
        float zoom = 2.0;
        vec2 mov = vec2(-1.0, 0.0);
        vec2 movement =  mov + mouse;

        //tot += (id.y == 0.0 && id.x > -2.0) ? vec3(nUV, 0.0) :  mandelbrot(uv2, max_steps, zoom, mov);
        tot += (id.y == 0.0 && id.x > -2.0) ? julia(nUV, max_steps, zoom, movement):  mandelbrot(uv2, max_steps, zoom, mov);
    }
    tot /= float(AA*AA);

    GAMMA(tot);
    fragColor = vec4(tot, 1.0);
}