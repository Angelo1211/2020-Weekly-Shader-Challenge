#iChannel0 "self"

#define M_PI 3.1415926535
#define M_TAU M_PI*2.0

#define DEBUG 0

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

float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
  vec3 pa = p - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}

float
sdRail(vec3 p)
{
    vec3 r1A = vec3(0.0, 0.0, -1.0);
    vec3 r1B = vec3(0.0, 0.0, 0.1);
    float r1r = 0.02;

    vec3 r2B = vec3(0.0, 1.7, 04.0);

    float r1 = sdCapsule(p - vec3(0.45, 0.2, 0.0), // pos
                             r1A, // start
                             r1B, // end
                             r1r); // radius

    float r2 = sdCapsule(p - vec3(0.45, 0.2, 00.0), // pos
                             r1B, // start
                             r2B, // end
                             r1r); // radius
    
    r1 = min(r1, r2);

    vec3 r3B = vec3(r2B.xy, r2B.z + 0.5);

    r2 = sdCapsule(p - vec3(0.45, 0.2, 00.0), // pos
                             r2B, // start
                             r3B, // end
                             r1r); // radius
    r1 = min(r1, r2);

    vec3 r4B = vec3(r3B.x, r3B.y + r2B.y + 0.20, r3B.z + 4.0);

    r2 = sdCapsule(p - vec3(0.45, 0.2, 00.0), // pos
                             r3B, // start
                             r4B, // end
                             r1r); // radius
    r1 = min(r1, r2);

    vec3 r5B = vec3(r4B.x, r4B.y , r4B.z + 4.0);

    r2 = sdCapsule(p - vec3(0.45, 0.2, 00.0), // pos
                             r4B, // start
                             r5B, // end
                             r1r); // radius
    r1 = min(r1, r2);

    return r1;
}

float
sdGround(vec3 p)
{
    float d = p.y;

    float steps = floor(p.z* 5.0);

    if ( p.z > 0.0 && p.z < 10.0)
    {
        d -= steps * 0.08 - 0.0 ;
    }

    //IQ steps https://www.shadertoy.com/view/ttBXRG
    float i = floor(d);
    float f = fract(d);
    float k = 4.0;
    float a = 0.5*pow(2.0*((f<0.5)?f:1.0-f), k);
    f = (f<0.5)?a:1.0-a;
    
    return i+f;
}

//union op
vec2
uop(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

//mirror op
vec3
mop(vec3 p)
{
    float off = 0.2;
    p.x = abs(p.x + off)- off;
    return p;
}

#define UOP(dist, id) res = uop(res, vec2(dist, id))

#define BOX_ID 0.0

#define GROUND_ID 1.0
#define LEFT_ID 2.0
#define RIGHT_ID 3.0
#define STAIRS_ID 4.0
#define RAIL_ID 5.0
#define ROOM_ID 6.0
#define CEIL_ID 7.0

#define EPSI 0.004
vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    float o = -1.4; //side offset
    float h = 300.5; // height of staircase walls
    UOP(sdGround(p - vec3(0.0, -0.1, 0.0)), GROUND_ID); 
    UOP(sdBox(p - vec3(0.02 + o, 0.0, 0.0), vec3(EPSI, h, 20.0)), LEFT_ID); 
    UOP(sdBox(p - vec3(1.99 + o, 0.0, 0.0), vec3(EPSI, h, 20.0)), RIGHT_ID); 
    UOP(sdBox(p - vec3(0.0, 09.1, 0.0), vec3(20.0,EPSI, 25.0)), CEIL_ID); 
    UOP(sdBox(p - vec3(0.0, 10.1, 20.1), vec3(20.0,20.0, EPSI)), ROOM_ID); 
    UOP(sdBox(p - vec3(o, 7.9, 17.0), vec3(0.1, 0.1, 0.2)), BOX_ID);
    UOP(sdRail(mop(p)), RAIL_ID);


    return res;
}

#define MAX_STEPS 2000
#define MIN_DIST 0.001
#define MAX_DIST 50.0
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

vec3 roomCol = vec3(0.01, 0.02, 0.8);

Material
GetMaterialFromID(float id, vec3 p, vec3 N)
{
    Material mat;
    //Default
    mat.col = vec3(1.0);
    mat.emi = 0.0;
    mat.rough = 1.0; //1.0 is maximum roughness 0.0 is perfectly reflective

    if(id == BOX_ID)
    {
        mat.col = vec3(0.0, 0.8, 0.0);
        mat.emi = 2.6;
    }
    else if(id == RAIL_ID) 
    {
        float r = length(p.xy);
        float a = atan(p.y, p.x);

        float dir = dot(N, vec3(0.0, -1.0, 0.0));
        if(abs(dir - 1.0) < 0.4)
        {
            mat.emi = 1.6;
            mat.col = vec3(1.0, 0.0, 0.0);
        }
        else
        {
            mat.col = vec3(0.5);
            mat.rough = 0.2;
        }
    }
    else if (id == ROOM_ID)
    {
        mat.col = roomCol;
        mat.emi = 1.0;
    }
    else if(id == LEFT_ID || id == RIGHT_ID)
    {
        mat.col = vec3(0.27, 0.27, 0.27);
        mat.rough = 0.6;
    }
    else if(id == CEIL_ID)
    {
        mat.rough = 0.5;
    }
    return mat;
}

vec3
CosineWeightedRay(vec3 n , float seed)
{
    float u = hash(seed + 82.753);
    float v = hash(seed + 18.902);

    float a = M_TAU * v;
    u = 2.0*u - 1.0;


    return normalize(n + vec3(sqrt(1.0 - u*u) * vec2(cos(a), sin(a)),u));
}

float
CalcShadows(vec3 ro, vec3 rd)
{
    float k = 2.0;
    float res = 1.0;
    for(float t = 0.012; t < MAX_DIST;)
    {
        float h = Map(ro + t*rd).x;
        
        if(h < MIN_DIST) return 0.0;
        res = min(res, h*k/t);
        t += h;
    }

    return res;
}

vec3
CalcRayDirection(vec3 originalRd, vec3 reflectionDir, vec3 normal, float rough, float seed)
{
    vec3 newRd = vec3(0.0);
    vec3 randDir = CosineWeightedRay(normal, seed);
    if(rough >= 1.0)
    {
        newRd = randDir;
    }
    else
    {
        newRd = reflectionDir*(saturate(1.0 - rough)) + rough * randDir;
        newRd = normalize(newRd);
    }

    return newRd;
}

vec3 sunCol = vec3(0.8, 0.7, 0.8);
vec3 skyCol = vec3(0.0, 0.2, 0.8);
vec3 sunDir = vec3(1.0, 1.3, 0.0);

#define GI_BOUNCES 2
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
    float t = 0.0;

    for(int bounce = 0; bounce < GI_BOUNCES; ++bounce)
    {
        //Scene traversal
        vec2 res = RayMarch(ro, rd);
        t = res.x;
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
        if(bounce == 0) depth = t;

        //Geometry
        vec3 P = ro + t*rd;
        vec3 N = CalcNormal(P);
        vec3 R = reflect(rd, N);

        //Material
        Material mat = GetMaterialFromID(id, P, N);
        rayCol *=mat.col;

        //Lighting
        vec3 lAcc =  vec3(0.0);
        vec3 L = normalize(sunDir);
        float diff = saturate(dot(N, L));

        vec3 indirect = rayCol * mat.emi;

        //Shadowing
        float shadowed = CalcShadows(P, L);

        //Shading
        #if DEBUG
            tot = N;
            break;
        #else
            //lAcc += shadowed * diff * sunCol;
            lAcc += indirect;
            tot += lAcc * rayCol;
        #endif

        //Next Ray bounce
        ro = P;
        float timeSeed =  76.2 + 73.1*float(bounce) + rng_ + 17.7*float(iFrame);
        //rd = CosineWeightedRay(N, timeSeed);
        rd = CalcRayDirection(rd, R, N, mat.rough, timeSeed);
    }

    //Fog
    tot = mix(tot, vec3(roomCol), 1.0 - exp(-0.0008*depth*depth));

    return tot;
}

void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Seeding rng per pixel per frame
    rng_ = hash(dot(vec2(12.9898, 78.233), fragCoord)+ 1113.1*float(iFrame));

    //Camera setup
    float nearP = 0.79;
    float roll = 0.0;
    vec2 offset = - 0.5 + vec2(hash(rng_ + 10.852), hash(rng_ + 56.266));
    vec2 uv = ((fragCoord+offset) - 0.5*iResolution.xy)/iResolution.y;
    vec3 ta = vec3(0.0, 0.6, 00.0);
    vec3 ro = vec3(0.0, 0.4, -1.0);
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