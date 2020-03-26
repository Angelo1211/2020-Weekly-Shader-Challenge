#include "./common.glsl"

/*
    Reading this today:
    https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/simulating-sky/simulating-colors-of-the-sky

    Read the article for the first time, will implement tomorrow.
*/

//Raymarcher vars
#define MAX_STEPS 200
#define MIN_DIST 0.0001
#define MAX_DIST 2000.0

//Map vars
#define EARTH_ID 0.0
#define SPHERE_ID 1.0

//Common vars
vec3 sunDir = normalize(vec3(1.0, 1.0, 0.0));
const float earthRadius = 6360e3; // (m)
const float atmosphereRadius = 6420e3; // (m)
float time;

vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);
    UOP(sdSphere(p - vec3(0.1, 0.1, 0.0), 0.25), SPHERE_ID);
    return res;
}

vec2
RayMarch(vec3 ro, vec3 rd)
{
    vec2 res = vec2(-1.0, -1.0);
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        vec2 hit = Map(ro +t*rd);

        if((hit.x) < MIN_DIST)
        {
            res = vec2(t, hit.y);
            break;
        }
        t +=hit.x;
    }
    return res;
}

vec3
Render(vec3 ro, vec3 rd)
{
    //Ray Results
    vec3 col = vec3(0.0);

    vec2 res = RayMarch(ro, rd);
    float t  = res.x;
    float id = res.y;

    //Solids
    if(id >= 0.0)
    {
        //Geometry
        vec3 P = ro + t*rd;

        //Material
        col = vec3(1.0);

        //Lighting
        vec3 lin = vec3(0.0);

        //Shadowing

        //Shading
        lin += P;
        col *= lin;
    }
    else //Sky
    {
        col = vec3(0.0);
    }
    //Volumetrics?

    return (col);
}

void 
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Normalize and unNormalized uvs
    vec2 nuv = ((fragCoord) - 0.5*iResolution.xy)/iResolution.y;
    vec2 uv = ((fragCoord) / iResolution.xy)  - 0.5;

    //Init common vars
    //sunDir = vec3(0.0, 1.0, 0.0);
    time = iTime / 10.0;
    vec3 col = vec3(0.0);

    //We're standing a bit above the earth's surface looking about a meter ahead
    vec3 ro = vec3(0.0, 0.0 , -1.0);
    vec3 ta = vec3(0.0, 0.0, 0.0);

    //Init camera vars
    float nearp = 1.0;
    float roll = 0.0;
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(nuv, nearp));

    col = Render(ro, rd);

    GAMMA(col);
    fragColor = vec4(col, 1.0);
}