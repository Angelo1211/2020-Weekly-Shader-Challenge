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
    return length(max(q, 0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

vec3
opRep( in vec3 p, in vec3 c)
{
    vec3 q = mod(p+0.5*c,c)-0.5*c;
    return q;
}

float
sdTopBox(vec3 p, vec3 b)
{
    float d1 = sdBox(p, b); 
    vec3 q = opRep(p, vec3(0.8));
    float d2 = sdBox(q, vec3(0.08));

    return max(d1,-d2);
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

    UOP(sdSphere(p - vec3(00.3, -0.2, 0.3),      0.25), SPHERE_ID);
    vec3 q = p - vec3(-0.55, 0.0, -0.1);
    q.z = mod(q.z + 0.2, 0.2) - 0.2;
    UOP(   sdBox(q, vec3(EPS, 0.14, EPS)), BOX_ID);

    //Enclosing Box
    UOP(sdTopBox(p - vec3(00.0, 00.3, 00.0), vec3(0.6, EPS , 0.6)), TOP_BOX_ID);
    UOP(sdBox(p - vec3(00.0, -0.3, 00.0), vec3(0.6, EPS , 0.6)), BOTTOM_BOX_ID);
    UOP(sdBox(p - vec3(00.6, 00.0, 00.0), vec3(EPS, 0.6 , 0.6)), RIGHT_BOX_ID);
    UOP(sdBox(p - vec3(-0.6, 00.0, 00.0), vec3(EPS, 0.6 , 0.6)), LEFT_BOX_ID);
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

float
CalcShadow(vec3 ro, vec3 rd)
{
    for(float t = 0.02; t < MAX_DIST;)
    {
        float hit = Map(ro + rd*t).x;
        if(hit < MIN_DIST)
            return 0.0;
        t += hit;
    }
    return 1.0;
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
    if(id == RIGHT_BOX_ID)
    {
        col = vec4(vec3(0.0, 1.0, 0.6), 0.2);
    }
    if(id == LEFT_BOX_ID)
    {
        col = vec4(vec3(1.0, 0.3, 0.0), 0.0);
    }
    if(id == TOP_BOX_ID)
    {
        //col = vec4(vec3(1.0, 1.0, 1.0), 1.0);
    }
    if(id == BOTTOM_BOX_ID)
    {

    }
    if(id == BOX_ID)
    {
        col = vec4(vec3(1.0), 1.0);
    }
    if(id == SPHERE_ID)
    {
        col = vec4(vec3(1.0), 0.0);
    }

    return col;
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

vec3 skyCol = vec3(0.9, 0.8, 1.0);

#define GI_BOUNCES 3
vec3
Render(vec3 ro, vec3 rd, float seed)
{
    //Tallying variables
    vec3 tot; 

    //Original values
    vec3 oro = ro;
    vec3 ord = rd;

    vec3 rayColor = vec3(1.0);
    vec3 sunDir = normalize(vec3(0.2, 1.0, 0.3));
    vec3 sunCol = 1.0*vec3(1.2,0.9,0.7);

    float firstBounce = 0.0;

    //Global Illumination ray bounce 4 solids
    for(int bounce = 0; bounce < GI_BOUNCES; ++bounce)
    {
        //Scene traversal
        vec2 res = RayMarch(ro, rd);
        float t = res.x;
        float id = res.y;
        float emissivity;

        if(id < 0.0)
        {
            if (bounce == 0)
            {
               tot = skyCol; 
            }
            break;
        }
        if( bounce==0 ) firstBounce = t;

        //Geometry
        vec3 P = ro + t*rd;
        vec3 N = CalcNormal(P);

        //Material
        vec4 material = GetMaterial(id);
        rayColor *= material.xyz;
        emissivity = material.w;
        
        //Lighting
        vec3 iLight = vec3(0.0);
        vec3 indirectLight = rayColor * emissivity;
        float sunDif =  max(0.0, dot(sunDir, N));
        float sunSha = 1.0;
        if( sunDif > 0.00001 )
             sunSha = CalcShadow( P + N*0.001, sunDir);
        iLight += sunCol * sunDif * sunSha;

        //Shadowing

        //Shading
        iLight += indirectLight;

        tot += iLight;

        //GI ray re-positioning
        ro = P;
        vec3 randomRay = rayOnHemisphere(76.2 + 73.1*float(bounce) + seed + 17.7*float(iFrame), N);
        if(id == SPHERE_ID)
        {
            float rough = 0.1;
            rd = (1.0 - rough)*reflect(rd, N) + rough*randomRay;
        }
        else
        {
            rd = randomRay;
        }

    }

    // volumetrics
    float dt = 0.5;
    float density = 0.0;

#define STEPS 5
    for( int i=0; i<STEPS; i++ )
    {   
        float rand = hash(seed+1.31+13.731*float(i)+float(iFrame)*7.773);
        float t = clamp((firstBounce * rand), 0.5, firstBounce);
        vec3 pos = oro + ord*t;
        density += dt*CalcShadow( pos, sunDir );
    }
    tot += vec3(0.3)*pow(density,2.0)*sunCol*0.4;   //Volumetrics


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
    float nearP = 0.9;
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