#include "./common.glsl"
#iChannel0 "self"

#define WALL_ID 0.0
#define LEFT_WALL_ID 1.0
#define RIGHT_WALL_ID 2.0
#define SPHERE_ID 3.0
#define BOX_ID 4.0
#define LIGHT_ID 5.0
#define EPS 0.01

vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    //Interior
    UOP(sdSphere(p - vec3(0.2, 0.0, -0.5), 0.1), SPHERE_ID);
    vec3 q = p;
    q.xz = rotate(q.xz, -0.4);
    UOP(sdBox(q - vec3(-0.2, 0.0, -0.2), vec3(0.1, 0.3, 0.1)), BOX_ID);

    //Exterior box
    UOP(sdBox(p - vec3(0.0, -0.1, 0.0), vec3(0.5, EPS, 1.0)), WALL_ID);
    UOP(sdBox(p - vec3(-0.5, 0.2, 0.0), vec3(EPS, 0.5, 1.0)), LEFT_WALL_ID);
    UOP(sdBox(p - vec3(0.5, 0.2, 0.0), vec3(EPS, 0.5, 1.0)), RIGHT_WALL_ID);
    UOP(sdBox(p - vec3(0.0, 0.7, 0.0), vec3(0.5, EPS, 1.0)), LIGHT_ID);
    UOP(sdBox(p - vec3(0.0, 0.0, 0.3), vec3(1.0, 1.0, EPS)), WALL_ID);
    
    return res;
}

#define MAX_DIST 20.0
#define MAX_STEPS 200
#define MIN_DIST 0.0001 

vec2
RayMarch(vec3 ro, vec3 rd)
{
    vec2 res = vec2(-1.0, -1.0);
    float t = 0.00;
    vec2 hit;

    for(int i =0 ; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        hit = Map(ro + t *rd);
        if(abs((hit.x)) < t * MIN_DIST)
        {
            res = vec2(t, hit.y);
            break;
        }

        t += hit.x;
    }
    
    return res;
}

vec3
CalcNormal(vec3 p)
{
    vec2 e = vec2(0.0001, 0.0);
    return normalize(vec3(Map(p + e.xyy).x - Map(p - e.xyy).x,
                          Map(p + e.yxy).x - Map(p - e.yxy).x,
                          Map(p + e.yyx).x - Map(p - e.yyx).x
    ));
}

vec3
rayOnHemisphere(float seed, vec3 nor)
{
    float u = hash( 78.233 + seed);
    float v = hash( 10.873 + seed);

    float a = 6.2831853 * v;
    u = 2.0*u - 1.0;
    return normalize( nor + vec3(sqrt(1.0-u*u) * vec2(cos(a), sin(a)), u) );   
}

vec4
GetMaterial(float id)
{
    vec4 col = vec4(vec3(1.0), 00.0);

    if(id == RIGHT_WALL_ID)  col  = vec4(0.0, 1.0, 0.0, 00.0);
    if(id == LEFT_WALL_ID)   col  = vec4(1.0, 0.0, 0.0, 00.0);
    if(id == LIGHT_ID)       col  = vec4(vec3(1.0), 0.6);
    if(id ==  SPHERE_ID)     col  = vec4(vec3(1.0), 0.0);

    return col;
}

#define GI_BOUNCES 6
vec3
Render(vec3 ro, vec3 rd, float randfloat)
{
    vec3 tot = vec3(0.0);

    vec3 rayColor = vec3(1.0);

    //GI bounces
    for(int bounce = 0; bounce < GI_BOUNCES; ++bounce)
    {
        //Ray traversal
        vec2 res = RayMarch(ro, rd);
        float t = res.x;
        float id = res.y;

        //Geometry 
        vec3 P = ro + t * rd;
        vec3 N = CalcNormal(P);

        //Material
        vec4 material = GetMaterial(id);
        float emissivity = material.w; 

        //Lighting
        vec3 iLight = vec3(0.0);
        vec3 indirectLight = rayColor * emissivity;

        //Shading
        rayColor *= material.xyz;
        iLight += 1.00 * indirectLight;
        tot += iLight  * rayColor;

        //Next Bounce Ray Setup
        rd = rayOnHemisphere(76.2 + 73.1*float(bounce) + randfloat + 17.7*float(iFrame), N);
        ro  = P;
    }

    return tot;
}

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    //RNG 
    float seed = hash(dot(fragPos, vec2(12.9898, 78.233)) + 1131.1*float(iFrame));

    //Supersample antialiasing thru random jittering  
    vec2 offset = - 0.5  + vec2(hash(seed + 13.271), hash( seed + 63.216));
    vec2 uv = ((fragPos + offset) - 0.5*iResolution.xy) / iResolution.y;

    //Ray setup
    float roll = 0.0;
    float nearP = 0.75;
    vec3 ta = vec3(0.0, 0.18, 0.0);
    vec3 ro = ta + vec3(0.0, 0.0, -1.0);
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearP));

    //Color setup
    vec2 screen = fragPos / iResolution.xy;
    vec3 col = texture(iChannel0, screen).xyz;

    //First frame init to zero 
    if (iFrame == 0) col = vec3(0.0);

    //Trace path of single ray across multiple bounces
    col += Render(ro, rd, seed);

    fragColor = vec4(col,  1.0);
}