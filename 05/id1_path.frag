#iChannel0 "self"

#define M_PI 3.1415926535
#define M_TAU M_PI*2.0

float seed_;

vec2 
rotate(vec2 a, float b)
{
    float c = cos(b);
    float s = sin(b);
    return vec2(
        a.x * c - a.y * s,
        a.x * s + a.y * c
    );
}

float 
sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float 
sdTorus( vec3 p, vec2 t )
{
    return length( vec2(length(p.xz)-t.x,p.y) )-t.y;
}

float 
sdRoundedCylinder( vec3 p, float ra, float rb, float h )
{
    vec2 d = vec2( length(p.xz)-2.0*ra+rb, abs(p.y) - h );
    return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
}

float
hash(float p)
{
    p = fract(p *0.012);
    p *= p + 7.5;
    p *= p + p;
    return fract(p);
}

mat3
SetCamera(vec3 ro, vec3 ta, float roll)
{
    vec3 f, temp, r, u;
    f = normalize(ta - ro);
    temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    r = normalize(cross(temp, f));
    u = normalize(cross(f, r));

    return mat3(r, u, f);
}

float
sdSphere(vec3 p, float r)
{
    return length(p) - r;
}

#define UOP(dist, ID) res = uop(res, vec2(dist, ID))
vec2
uop(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

#define DEF_ID 0.0
#define LEFT_WALL_ID 1.0
#define RIGHT_WALL_ID 2.0
#define LIGHT_ID 5.0
#define CAKE_ID 6.0
#define TORUS_ID 7.0
#define CHERRY_ID 8.0

#define EPS 0.01
vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    //Interior
    if(p.x > -0.27 && p.x < 0.27) 
    if(p.z > -0.6 && p.z < 0.5) 
    if(p.y > -0.1 && p.y < 0.25) 
    {
        //Center cornerll box items
        UOP(sdSphere(p - vec3(0.07, 0.13, -0.18), 0.04), DEF_ID);
        vec3 q = p;
        q.xz = rotate(q.xz, -0.4);
        UOP(sdBox(q - vec3(-0.12, 0.0, -0.12), vec3(0.02, 0.2, 0.02)), DEF_ID);

        //Cake
        vec3 pCake = p - vec3(0.0f, 0.0f, -0.15f);
        float cakeRad = 0.13;
        //cakeRad -= 0.0005*(0.5 + 0.5*sin(200.0 * p.y));
        UOP(sdRoundedCylinder(pCake,  cakeRad, 0.012f, 0.08), CAKE_ID);

        //Candle
        vec3 pDecoration = pCake - vec3(0.0, 0.097, 0.0);   

        //Candy Spheres
        if(pDecoration.y > -0.01 && pDecoration.y < 0.058) //No need to evaluate this for every ray
        {
            float rSphere = 0.024;
            float radius = 0.21;
            float numElements = 8.0;
            vec3 ring = pDecoration;
            for(float i = 0.0; i < numElements; ++i){
                float angle = 2.0 * M_PI * i / numElements; 
                vec3 rotatedPos = ring - vec3(0.0 - radius*cos(angle), 0.0, -radius*sin(angle));
                float tRad = 0.005;
                tRad -= 0.0007*(0.5 + 0.5*sin(16.0 * atan(rotatedPos.x, rotatedPos.z)));
                UOP(sdTorus(rotatedPos, vec2( 0.02, tRad)),TORUS_ID);
                UOP(sdSphere(rotatedPos - vec3(0.0, rSphere, 0.0), rSphere ),CHERRY_ID);
            }
        }
    }

    //Exterior box
    {
        //Bottom wall
        UOP(sdBox(p - vec3(0.0, -0.1, 0.0), vec3(0.5, EPS, 1.0)), DEF_ID);
        UOP(sdBox(p - vec3(-0.5, 0.2, 0.0), vec3(EPS, 0.5, 1.0)), LEFT_WALL_ID);
        UOP(sdBox(p - vec3(0.5, 0.2, 0.0), vec3(EPS, 0.5, 1.0)), RIGHT_WALL_ID);

        //Ceiling wall
        UOP(sdBox(p - vec3(0.0, 0.7, 0.0), vec3(0.5, EPS, 1.0)), DEF_ID);
        UOP(sdBox(p - vec3(0.0, 0.7, 0.0), vec3(0.2, EPS, 0.2)), LIGHT_ID);

        //Back wall
        UOP(sdBox(p - vec3(0.0, 0.0, 0.3), vec3(1.0, 1.0, EPS)), DEF_ID);
    }

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
                          Map(p + e.yyx).x - Map(p - e.yyx).x
    ));

}

struct Material
{
    vec3 col;
    float emi;
    float rough;
    float fresnel;
    vec2 pad;
};

Material
GetMaterialFromID(float id, vec3 p, vec3 N)
{
    Material mat;
    //Default
    mat.col = vec3(1.0);
    mat.emi = 0.0;
    mat.rough = 1.0; //1.0 is maximum roughness 0.0 is perfectly reflective
    mat.fresnel = 0.0;
    if(id == DEF_ID) return mat; //fast path for default mat

    if(id == CAKE_ID)
    {
        mat.col = vec3(0.06, 0.04, 0.02);
    }
    else if(id == LEFT_WALL_ID)
    {
        mat.col = vec3(1.0, 0., 1.0);
    }
    else if(id == RIGHT_WALL_ID)
    {
        mat.col = vec3(0.0, 1.0, 1.0);
    }
    else if(id == LIGHT_ID)
    {
        mat.emi = 1.6;
    }
    else if(id == CHERRY_ID)
    {
        mat.col = vec3(0.8, 0.0, 0.0);
        mat.rough = 0.2;
        mat.fresnel = 1.0;
    }
    return mat;
}

vec3
CosineWeightedRay(vec3 N, float seed)
{
    float u = hash(seed + 70.93);
    float v = hash(seed + 21.43);

    float a = M_TAU*v;
    u = 2.0*u - 1.0;

    return(normalize(N + vec3(sqrt(1.0 - u*u)*vec2(cos(a), sin(a)), u)));
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

#define GI_BOUNCES 4
vec3
Render(vec3 ro, vec3 rd)
{
    //Ray setup
    vec3 tot = vec3(0.0);
    vec3 rayCol = vec3(1.0);

    for(int bounce = 0; bounce < GI_BOUNCES; ++bounce) 
    {
        //Unpacking Ray results
        vec2 res = RayMarch(ro, rd);
        float t = res.x;
        float id = res.y;

        //Geometry        
        vec3 P = ro + t*rd;
        vec3 N = CalcNormal(P);
        vec3 R = reflect(rd, N);

        //Material
        Material mat = GetMaterialFromID(id, P, N); 
        rayCol *= mat.col;
        float emi = mat.emi;
        float fresnel = mat.fresnel;

        //Lighting
        vec3 colAcc = vec3(0.0); 
        vec3 indirect = emi * rayCol;
        float fre = fresnel * pow( saturate(1.0+dot(N,rd)), 5.0 );

        //Shading
        colAcc += 1.00 * indirect;
        colAcc += 0.07 * fre;
        tot += colAcc;

        //Next bounce ray Dir
        float timeSeed =  76.2 + 73.1*float(bounce) + seed_ + 17.7*float(iFrame);
        rd = CalcRayDirection(rd, R, N, mat.rough, timeSeed);
        ro = P;
    }

    return tot;
}

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    //Random number generator
    float seed = dot(fragPos, vec2(12.9898, 78.233)) + 1131.1*float(iFrame);
    seed_ = hash(seed * 81.94);
    vec2 offset = - 0.5  + vec2(hash(seed + 13.271), hash( seed + 63.216));

    //Initializing color to the prev frame value
    vec2 screen = (fragPos) / iResolution.xy;
    vec3 col = texture(iChannel0, screen).xyz;
    if(iFrame == 0) col = vec3(0.0);

    //Camera setup
    float roll = 0.0;

    float nearP = 0.75;
    vec3 ta = vec3(0.0, 0.35, 0.0);
    vec3 ro = ta + vec3(0.0, 0.0, -1.0);
    mat3 cam = SetCamera(ro, ta, roll);
    vec2 uv = ((fragPos + offset) - 0.5*iResolution.xy) / iResolution.y;
    vec3 rd = cam * normalize(vec3(uv, nearP));

    col += Render(ro, rd);

    fragColor = vec4(col, 1.0);
}   