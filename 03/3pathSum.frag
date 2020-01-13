#iChannel0 "self"

float
hash(float seed)
{
    return fract(sin(seed)*43758.5453);
}

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 f, r, u, upRoll;

    f = normalize(target - eye);
    upRoll = normalize(vec3(sin(roll), cos(roll), 0.0));
    r = normalize(cross(upRoll, f));
    u = normalize(cross(f, r));

    return mat3(r, u, f);
}

vec2
uop(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

float
sdSphere(vec3 n, float r)
{
    return length(n) - r;
}

float
sdBox(vec3 p, vec3 b)
{
    vec3 q = abs(p) - b;
    return length(max(q, 0.0));// + min(max(q.x,max(q.y,q.z)),0.0);
}

#define UOP(dist, ID) res = uop(res, vec2(dist, ID))
#define SPHERE_ID 1.0
#define BOTTOM_BOX_ID 2.0
#define TOP_BOX_ID 3.0
#define RIGHT_BOX_ID 4.0
#define LEFT_BOX_ID 5.0
#define BACK_BOX_ID 6.0
#define BOX_ID 7.0
#define EPS 0.01

vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    UOP(sdSphere(p - vec3(00.3, -0.2, -0.1),      0.25), SPHERE_ID);
    UOP(   sdBox(p - vec3(-0.2, -0.1, -0.2), vec3(0.1)), BOX_ID);

    //Enclosing Box
    UOP(sdBox(p - vec3(00.0, 00.3, 00.0), vec3(0.6, EPS , 0.6)), TOP_BOX_ID);
    UOP(sdBox(p - vec3(00.0, -0.3, 00.0), vec3(0.6, EPS , 0.6)), BOTTOM_BOX_ID);
    UOP(sdBox(p - vec3(00.6, 00.0, 00.0), vec3(EPS, 0.6 , 0.6)), LEFT_BOX_ID);
    UOP(sdBox(p - vec3(-0.6, 00.0, 00.0), vec3(EPS, 0.6 , 0.6)), RIGHT_BOX_ID);
    UOP(sdBox(p - vec3(00.0, 00.0, 00.6), vec3(0.6, 0.6 , EPS)), BACK_BOX_ID);

    return res;
}

#define MAX_STEPS 100
#define MIN_DIST 0.001
#define MAX_DIST 20.0
vec2
RayMarch(vec3 ro, vec3 rd)
{
    vec2 res = vec2(-1.0, -1.0);
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        vec2 hit = Map(ro + t*rd);

        if(abs(hit.x) < t*MIN_DIST)
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
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(Map(p + e.xyy).x - Map(p - e.xyy).x,
                          Map(p + e.yxy).x - Map(p - e.yxy).x,
                          Map(p + e.yyx).x - Map(p - e.yyx).x
    ));

}

vec4
GetMaterial(float id)
{
    vec4 col = vec4(1.0, 1.0, 1.0, 0.0);

    return col;
}

vec3 skyCol = vec3(0.9, 0.8, 1.0);

#define GI_BOUNCES 1
vec3
Render(vec3 ro, vec3 rd, float seed)
{
    //Tallying variables
    vec3 tot, col; 

    //Original values
    vec3 oro, ord;

    //Global Illumination ray bounce 4 solids
    for(int bounce = 0; bounce < GI_BOUNCES; ++bounce)
    {
        //Scene traversal
        vec2 res = RayMarch(ro, rd);
        float t = res.x;
        float id = res.y;

        if(id < 0.0)
        {
            if (bounce == 0)
            {
               tot = skyCol; 
            }
            break;
        }

        //Geometry
        vec3 P = ro + t*rd;
        vec3 N = CalcNormal(P);

        //Material
        vec4 material = GetMaterial(id);
        

        //Lighting

        //Shadowing

        //Shading
        col = N;

        tot += col;

        //GI ray re-positioning
        ro = P;
    }

    //Volumetrics

    return tot;
}

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    //Different seed number for each pixel each frame
    float seed = hash(dot(vec2(12.9898, 78.233),fragPos) + 1113.1*float(iFrame));

    //Anti-aliasing thru jittering the pixel slightly each frame
    vec2 offset = - 0.5  + vec2(hash(seed + 13.271), hash( seed + 63.216));
    vec2 uv = ((fragPos + offset) - 0.5*iResolution.xy)/ iResolution.y;

    //Camera setup
    float nearP = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0, 0.0, 0.0);
    vec3 ro = ta + vec3(0.0, 0.0, -1.0);
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearP));

    //Adding to prev frame result
    vec2 screen = fragPos.xy / iResolution.xy;
    vec3 col = texture(iChannel0, screen).xyz;
    if (iFrame == 0 )  col = vec3(0.0);

    col += Render(ro, rd, seed);

    fragColor = vec4(col,1.0);
}