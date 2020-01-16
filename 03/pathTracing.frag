#iChannel0 "self"

//GLOBALS
float seed_ = 0.0;

float 
hash(float p)
{ 
    p = fract(p* 0.011);
    p *= p + 7.5;
    p *= p + p;
    return fract(p);
}

vec3
CosineWeightedRay(vec3 normal, float seed)
{
    float u = hash( 78.233 + seed);
    float v = hash( 10.873 + seed);

    float a = 6.2831853 * v;
    u = 2.0*u - 1.0;
    return normalize( normal + vec3(sqrt(1.0-u*u) * vec2(cos(a), sin(a)), u) );   
}

mat3
SetCamera(vec3 eye, vec3 tar, float roll)
{
    vec3 f, r, u, upTemp;
    f = normalize(tar - eye);
    upTemp = normalize(vec3(sin(roll), cos(roll), 0.0));
    r = normalize(cross(upTemp, f)); 
    u = normalize(cross(f, r));

    return mat3(r, u, f);
}

float
sdSphere(vec3 p, float r)
{
    return length(p) - r;
}

float
sdBox(vec3 p, vec3 s)
{
    vec3 q = abs(p) - s;
    return length(max(q,0.0)) + min(max(max(q.x, q.y), q.z), 0.0);
}

vec2 
uop(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

vec3
repetitionOp(vec3 p, vec3 cellSize)
{
    return mod(p + +0.5*cellSize, cellSize) - 0.5*cellSize;
}

float
sdCircle(vec3 p, float r, float t)
{
    float d1 = sdBox(p, vec3(r, r, t));

    float d2 = sdSphere(p, r);

    return max(d1, d2);
}

#define UOP(dist, id) res = uop(res, vec2(dist, id))

#define SPHERE1_ID 0.0
#define SPHERE2_ID 1.0

#define BOTTOM_ID 2.0
#define TOP_ID 3.0
#define LEFT_ID 4.0
#define RIGHT_ID 5.0
#define BACK_ID 6.0
#define FRONT_ID 7.0

#define WITNESS_TOP 8.0
#define WITNESS_BODY 9.0
#define WITNESS_END 10.0

#define EPSI 0.005

vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);
    //Random box
    //UOP(sdSphere(p - vec3(00.5, 00.2, 00.0),      0.25),           SPHERE1_ID);
    //UOP(sdSphere(p - vec3(-0.5, 00.2, 00.0),      0.25),           SPHERE2_ID);

    //Enclosure
    UOP(sdBox(p - vec3(00.0, -0.1, 00.0), vec3(01.0, EPSI, 1.0)), BOTTOM_ID);
    UOP(sdBox(p - vec3(00.0, 01.0, 00.0), vec3(01.0, EPSI, 1.0)), TOP_ID);
    UOP(sdBox(p - vec3(01.0, 00.0, 00.0), vec3(EPSI, 01.0, 1.0)), LEFT_ID);
    UOP(sdBox(p - vec3(-1.0, 00.0, 00.0), vec3(EPSI, 01.0, 1.0)), RIGHT_ID);
    UOP(sdBox(p - vec3(00.0, 00.0, -1.0), vec3(01.0, 01.0, EPSI)), FRONT_ID);
    UOP(sdBox(p - vec3(00.0, 00.0, 01.0), vec3(01.0, 01.0, EPSI)), BACK_ID);

    //Witness Symbol
    //UOP(sdCircle(p - vec3(-0.5, 00.5, 01.0), 0.1, 0.1), WITNESS_TOP);
    UOP(   sdBox(p - vec3(-0.5, 00.5, 01.0), vec3(0.085, 0.085, EPSI )), WITNESS_TOP);


    return res;
}

#define MAX_STEPS 400
#define MAX_DIST 200.0
#define MIN_DIST 0.001
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
    vec4 color; // RGB (unused 4th channel)
    vec4 properties; // Emissive, Roughness, unused 3rd & 4th channel
};

Material
GetMaterial(vec3 p, vec3 n, float id)
{
    Material mat;
    mat.color = vec4(vec3(1.0), -1.0);
    mat.properties = vec4(0.0, 1.0, -1.0, -1.0);

    if(id == SPHERE1_ID)
    {
        mat.color.xyz = vec3(1.0, 1.0, 1.0);
        mat.properties.x = 0.0;  //Emissive 
        mat.properties.y = 1.0 * mod(floor(p.x * 40.0), 2.0);  //Roughness (0.0reflective, 1.0diffuse)
    }
    else if(id == SPHERE2_ID)
    {
        mat.properties.y = 1.0 * mod(floor(p.y * 40.0), 2.0);  //Roughness (0.0reflective, 1.0diffuse)
        mat.color.xyz = vec3(1.0, 1.0, 1.0);
        mat.properties.x = 0.0;  //Emissive 
    }
    else if(id == BOTTOM_ID)
    {

    }
    else if(id == TOP_ID)
    {
        mat.color.xyz = vec3(1.0, 1.0, 1.0);
        mat.properties.x = 0.0;  //Emissive 
        mat.properties.y = 1.0;  //Roughness (0.0reflective, 1.0diffuse)
    }
    else if(id == LEFT_ID)
    {
        mat.color.xyz = vec3(0.0, 0.7, 1.0);
        mat.properties.x = 0.5;  //Emissive 
        mat.properties.y = 1.0;  //Roughness (0.0reflective, 1.0diffuse)

    }
    else if(id == RIGHT_ID)
    {
        mat.color.xyz = vec3(0.9, 0.4, 0.0);
        mat.properties.x = 0.5;  //Emissive 
        mat.properties.y = 1.0;  //Roughness (0.0reflective, 1.0diffuse)

    }
    else if(id == BACK_ID)
    {

    }
    else if(id == FRONT_ID)
    {

    }
    else if(id == WITNESS_TOP)
    {
        mat.properties.x = 0.5;  //Emissive 
    }
    else if(id == WITNESS_BODY)
    {
        mat.properties.x = 0.5;  //Emissive 
    }
    else if(id == WITNESS_END)
    {
        mat.properties.x = 0.5;  //Emissive 
    }

    return mat;
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

const vec3 skyCol = vec3(0.5, 0.8, 0.9);

#define GI_BOUNCES 10
vec3
Render(vec3 ro, vec3 rd)
{
    //GI accumulation setup
    vec3 tot = vec3(0.0);

    float firstBounceDist = 0.0;

    vec3 rayCol = vec3(1.0);

    //Global illumination loop for solid lighting
    for(int bounce = 0; bounce < GI_BOUNCES; ++bounce)
    {
        //Ray traversal results
        vec2 res = RayMarch(ro, rd);
        float t = res.x;
        float id = res.y;

        if(id < 0.0)
        {
            if(bounce == 0)
            {
                tot = skyCol;
            }
            break;
        }

        if(bounce == 0 ) firstBounceDist = t;

        //Geometry
        vec3 P = ro + t*rd;
        vec3 N = CalcNormal(P);
        vec3 R = reflect(rd, N);

        //Material
        Material mat = GetMaterial(P, N, id);
        rayCol *= mat.color.xyz;
        float emissiveness = mat.properties.x;
        float roughness = mat.properties.y;

        //Lighting
        vec3 lightAccumulation = vec3(0.0);
        vec3 indirectLight = emissiveness * rayCol;

        //Shadowing

        //Shading
        lightAccumulation += indirectLight;

        //Light accumulation
        lightAccumulation *= pow(0.65, float(bounce));
        tot += lightAccumulation;


        //Next bounce setup
        float timeSeed =  76.2 + 73.1*float(bounce) + seed_ + 17.7*float(iFrame);
        ro = P;
        rd = CalcRayDirection(rd, R, N, roughness, timeSeed);
    }

    //Hacky Volumetrics

    //Distance fog
    tot = mix(tot, skyCol, 1.0 - exp(-0.002*firstBounceDist *firstBounceDist));



    return tot;
}

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    //Generating a different random number per frame per pixel
    seed_ = hash( dot(vec2(12.9898, 78.233), fragPos ) + float(iFrame)*1113.1);

    //Getting prev frame result for additive blend 
    vec2 screen = fragPos / iResolution.xy;
    vec3 col = texture(iChannel0, screen).xyz;
    if (iFrame == 0) col = vec3(0.0);

    //Camera setup
    float nearp = 0.7;
    float roll = 0.0;
    vec2 offset = -0.5 + vec2(hash(seed_ + 58.21), hash(seed_ + 18.61));
    vec2 uv = ((fragPos + offset) - 0.5*iResolution.xy) / iResolution.y;
    vec3 ta = vec3(0.0, 0.2, 0.0);
    vec3 ro = ta + vec3(0.0, 0.0, -0.97);
    mat3 cam  = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearp));  

    //Rendering the path of one ray
    col += Render(ro, rd);
    //Debug rng
    //col = vec3(seed_);

    fragColor = vec4(col, 1.0);
}