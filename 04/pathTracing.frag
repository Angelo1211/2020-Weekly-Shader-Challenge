#iChannel0 "self"

#define M_PI 3.1415926535
#define M_TAU M_PI*2.0

float rng_ = 0.0;

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 f, temp, r, u;
    f = normalize(target - eye);
    temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    r = normalize(cross(temp, f));
    u = cross(f, r); 

    return mat3(r, u, f);
}

float
hash(float p)
{
    p = fract(p *0.011);
    p *= p + 7.5;
    p *= p + p;
    return fract(p);
}

float
sdBox(vec3 p, vec3 sides)
{
    vec3 q = abs(p) - sides;
    return length(max(q, 0.0)) - min(max(q.z, max(q.x, q.y)), 0.0);
}

float
sdSphere(vec3 p, float r)
{
    return length(p) - r; 
}

vec2
uop(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

#define UOP(dist, id) res = uop(res, vec2(dist, id))

#define SPHERE_ID 0.0
#define GROUND_ID 1.0

#define EPSI 0.004
vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    UOP(sdSphere(p - vec3(0.0, 0.2, 0.0), 0.25), SPHERE_ID);
    UOP(sdBox(p - vec3(0.0, -0.1, 0.0), vec3(0.5,EPSI, 0.5)), GROUND_ID);


    return res;
}

#define MAX_STEPS 200
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
                          Map(p + e.yyx).x - Map(p - e.yyx).x));
}

struct Material
{
    vec3 col; //r,g,b
    float emi;
    float rough;
    vec3 pad;
};

Material
GetMaterialFromID(float id)
{
    Material mat;
    //Default
    mat.col = vec3(1.0);
    mat.emi = 0.0;
    mat.rough = 1.0; //1.0 is maximum roughness 0.0 is perfectly reflective

    if(id == SPHERE_ID)
    {
        mat.col = vec3(1.0, 1.0, 0.8);
        mat.emi = 0.6;
    }

    return mat;
}

vec3
CosineWeightedRay(vec3 n , float seed)
{
#if 1
    float u = hash(seed + 19.1945);
    float v = hash(seed + 77.1719);

    float a = M_TAU * v;
    u = 2.0*u - 1.0;

    return normalize(n + vec3(sqrt(1.0 - u*u) *vec2(cos(a), sin(a)), u ) );

#else
    float u = hash( 78.233 + seed);
    float v = hash( 10.873 + seed);

    float a = 6.2831853 * v;
    u = 2.0*u - 1.0;
    return normalize( n + vec3(sqrt(1.0-u*u) * vec2(cos(a), sin(a)), u) );   
#endif
}

vec3 skyCol = vec3(0.0, 0.2, 0.8);

#define GI_BOUNCES 3
vec3
Render(vec3 ro, vec3 rd)
{
    //Global illumination tracking vars
    vec3 tot = vec3(0.0);
    vec3 rayCol = vec3(1.0);

    //Original data
    vec3 oro = ro;
    vec3 ord = rd;
    float depth = 0.0;

    for(int bounce = 0; bounce < GI_BOUNCES; ++bounce)
    {
        //Scene traversal
        vec2 res = RayMarch(ro, rd);
        float t = res.x;
        float id = res.y;

        //First hit
        if (id < 0.0)
        {
            //you hit the sky
            if (bounce == 0)
            {
                //If you hit it on the first bounce that's your final color
                tot = skyCol;
            }
            break;
        }

        //Geometry
        vec3 P = ro + t*rd;
        vec3 N = CalcNormal(P);
        vec3 R = reflect(rd, N);

        //Material
        Material mat = GetMaterialFromID(id);
        rayCol *=mat.col;

        //Lighting
        vec3 lAcc =  vec3(0.0);
        vec3 indirect = rayCol * mat.emi;

        //Shadowing

        //Shading
        lAcc = indirect;
        tot += lAcc * rayCol;

        //Next Ray bounce
        ro = P;
        float timeSeed =  76.2 + 73.1*float(bounce) + rng_ + 17.7*float(iFrame);
        rd = CosineWeightedRay(N, timeSeed);
    }

    return tot;
}

void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Seeding rng per pixel per frame
    rng_ = hash(dot(vec2(12.9898, 78.233), fragCoord)+ 1113.1*float(iFrame));

    //Camera setup
    float nearP = 1.0;
    float roll = 0.0;
    vec2 offset = - 0.5 + vec2(hash(rng_ + 10.852), hash(rng_ + 56.266));
    vec2 uv = ((fragCoord+offset) - 0.5*iResolution.xy)/iResolution.y;
    vec3 ta = vec3(0.0, 0.2 ,0.0);
    vec3 ro = ta + vec3(0.0, 0.0, -1.0);
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearP));

    //Adding to prev color
    vec2 screen = fragCoord / iResolution.xy;
    vec3 col = texture(iChannel0, screen).xyz;
    if( iFrame == 0) col = vec3(0.0); 

    //Render
    col += Render(ro, rd);

    //Noise debug
    //col += vec3(rng_);

    fragColor = vec4(col, 1.0);    
}