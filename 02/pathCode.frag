#iChannel0 "self"

#define GI_BOUNCES 3
#define MAX_DIST 200.0
#define MAX_STEPS 500
#define MIN_DIST 0.0001 

vec3
xMirror(vec3 p)
{
    p.x = abs(p.x);
    return p;
}

vec2 
uop(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

float
sdPlane( vec3 p, vec4 n )
{
    // n must be normalized
    return dot(p,n.xyz) + n.w;
}

float
sdSphere(vec3 p, float r)
{
    return length(p) - r;
}

float
sdGround(vec3 p)
{
    return p.y;
}

float 
sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float
sdTop(vec3 p, vec4 n)
{
    float d;

    // n must be normalized
    float d1 = dot(p,n.xyz) + n.w;

    float d2 = sdBox(p - vec3(0.0, 0.0, 1.0), vec3(0.2, 1.0, 0.2));

    d = max(d1, -d2);

    return d;
}

float 
hash(float seed)
{
    return fract(sin(seed)*43758.5453 );
}

mat3
SetCamera(vec3 eye, vec3 tar, float roll)
{
    vec3 f, r, u;
    f = normalize(tar - eye);
    vec3 upRoll = normalize(vec3(sin(roll), cos(roll), 0.0));
    r = normalize(cross(upRoll, f));
    u = normalize(cross(f, r));

    return mat3(r, u, f);
}

#define UOP(DIST, ID) res = uop(res, vec2(DIST, ID)); 

#define WALL_ID 0.0
#define LEFT_WALL_ID 1.0
#define RIGHT_WALL_ID 2.0
#define SPHERE_ID 3.0

float
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    UOP(sdSphere(p - vec3(0.1, 0.0, -0.5), 0.1), SPHERE_ID);
    UOP(sdGround(p + 0.1), WALL_ID);
    UOP(sdPlane((p) - vec3(0.4, 0.0, 0.0), normalize(vec4(-1.0, 0.0, 0.0, 0.0))), LEFT_WALL_ID);
    UOP(sdPlane((p) - vec3(-0.4, 0.0, 0.0), normalize(vec4(1.0, 0.0, 0.0, 0.0))), RIGHT_WALL_ID);
    //Back wall
    UOP(sdPlane((p) - vec3(0.0, 0.0, 0.1), normalize(vec4(0.0, 0.0, -1.0, 0.0))), WALL_ID);

    //UOP(  sdTop((p) - vec3(0.0, 0.4, 0.0), normalize(vec4(0.0, -1.0, 0.0, 0.0))), WALL_ID);

    return res.x;
}

float
RayMarch(vec3 ro, vec3 rd)
{
    float res = -1.0; 
    float t = 0.001;

    for(int i =0 ; i < MAX_STEPS; ++i)
    {
        float h = Map(ro + t *rd);
        if(h < MIN_DIST || t > MAX_DIST ) break;
        t += h;
    }
    
    if (t < MAX_DIST) res = t;

    return res;
}

vec3
CalcNormal(vec3 p)
{
    vec2 e = vec2(0.0001, 0.0);
    return normalize(vec3(Map(p + e.xyy) - Map(p - e.xyy),
                          Map(p + e.yxy) - Map(p - e.yxy),
                          Map(p + e.yyx) - Map(p - e.yyx)
    ));
}

float
CalcShadow(vec3 ro, vec3 rd)
{
    float res = 0.0;
    float t = 0.004;

    for(int i = 0; i < MAX_STEPS; ++i)
    {
        float h = Map(ro + rd *t);
        if( h < MIN_DIST || t > MAX_DIST) break;
        t += h;
    }

    if (t > MAX_DIST) res = 1.0;

    return res;
}


//vec3 skyCol =  4.0*vec3(0.2,0.35,0.5);
vec3 skyCol =  vec3(0.0,0.35,0.5);

vec3
rayOnSphere(float seed, vec3 nor)
{
    float u = hash( 78.233 + seed);
    float v = hash( 10.873 + seed);

    float a = 6.2831853 * v;
    u = 2.0*u - 1.0;
    return normalize( nor + vec3(sqrt(1.0-u*u) * vec2(cos(a), sin(a)), u) );   
}

vec3
Render(vec3 ro, vec3 rd, float randfloat)
{
    vec3 tot = vec3(0.0);

    float primaryRay = 0.0;

    //GI bounces
    for(int bounce = 0; bounce < GI_BOUNCES; ++bounce)
    {
        float t = RayMarch(ro, rd);

        //Early out if you hit the sky
        if(t < 0.0)
        {
            //But not before adding sky color only once 
            if(bounce == 0)
                return skyCol;
            break;
        }

        //Record how much the primary travelled
        if(bounce == 0) 
            primaryRay = t;

        //Geometry 
        vec3 P = ro + t * rd;
        vec3 N = CalcNormal(P);

        //Material
        vec3 material = vec3(0.4);

        //Lighting
        vec3 iLight = vec3(0.0);
        vec3 L = normalize(vec3(0.0, 1.0, 0.0));
        float sunDiff = saturate(dot(N, L));

        vec3 skyPoint = rayOnSphere(randfloat + 7.1*float(iFrame) + 5681.123 + float(bounce)*92.13,N);
        float skyShadow = CalcShadow(P, skyPoint);

        //Shadowing only if there is some light
        if (sunDiff > 0.0001)
        {
            sunDiff *= CalcShadow(P, L); 
        }

        //Shading
        iLight += 1.00 * sunDiff * vec3(1.0, 0.8, 0.6);
        iLight += 1.00 * skyShadow * skyCol;
        
        tot += iLight ;

        rd = rayOnSphere(76.2 + 73.1*float(bounce) + randfloat + 17.7*float(iFrame), N);

        ro  = P;
    }

    return tot;
}

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    //RNG 
    float seed = hash(dot(fragPos, vec2(12.9898, 78.233)) + 1131.1*float(iFrame));

    //Offset gives us jitter supersample antialiasing thru random jittering
    vec2 offset = - 0.5  + vec2(hash(seed + 13.271), hash( seed + 63.216));
    vec2 uv = ((fragPos + offset) - 0.5*iResolution.xy) / iResolution.y;

    //Ray setup
    float roll = 0.0;
    float nearP = 0.8;
    vec3 ta = vec3(0.0, 0.0, 0.0);
    vec3 ro = ta +  vec3(0.0, 0.2, -1.0);
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearP));

    //Color setup
    vec2 screen = fragPos / iResolution.xy;
    vec3 col = texture(iChannel0, screen).xyz;

    //First frame init to zero 
    if (iFrame == 0) col = vec3(0.0);

    //Path trace single ray add result to previous buffer
    col += Render(ro, rd, seed);

    fragColor = vec4(col,  1.0);
}