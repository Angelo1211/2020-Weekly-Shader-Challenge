#include "./common.glsl"
/*
    Reading this today:
    https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/simulating-sky/simulating-colors-of-the-sky

    Restarting, working o
*/

//const variables
const float R_earth = 6360e3;
const float R_atmo  = 6420e3;

//uniforms
float time = 0.0;

vec2
RayIntersectSphere(vec3 ro, vec3 rd, float r)
{

}

vec3
Render(vec3 ro, vec3 rd)
{
    //Ray setup
    float t0, t1;
    vec3 col;

    col += rd;

    return col;
}

void 
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Normalize and unNormalized uvs
    vec2 nuv = ((fragCoord) - 0.5*iResolution.xy)/iResolution.y;
    vec2 uv = ((fragCoord) / iResolution.xy)  - 0.5;

    //Init common vars
    vec3 col = vec3(0.0);
    time = iTime / 10.0;
    vec2 p = nuv;

    //Sky fish-eye representation
    float z2 = length(p);
    float phi = atan(p.y, p.x);
    float theta = acos(1.0 - z2);

    //One meter above earth surface
    vec3 ro = vec3(0, R_earth + 1.0, 0.0 );

    vec3 rd = vec3(sin(theta) * cos(phi),
                    cos(theta),
                    sin(theta) * sin(phi));

    col += Render(ro, rd);

    GAMMA(col);
    fragColor = vec4(col, 1.0);
}