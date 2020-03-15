#include "./common.glsl"

vec3 _temp;

float
sdRing(vec3 p)
{
    vec3 pos = p - vec3(-0., -0.00, 0.0);

    float r = length(vec2(pos.x, pos.z));
    
    //pos.xy = rotate(pos.xy, -0.2);
    float ringSize = 2.0;
    float d = sdBox(pos, vec3(ringSize, 0.00002, ringSize));

    if(r > ringSize - 0.2 || r < 1.1) d += 0.01;

    return d;
}

#define SATURN_ID 0.0
#define MOON_ID 1.0
#define RING_ID 2.0
vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    vec3 saturnPos = vec3(0., 0.00, 0.0);
    UOP(sdSphere(p - saturnPos, 0.80), SATURN_ID);

    //UOP(sdSphere(p - vec3(-0.013, -0.027, -0.9), 0.006), MOON_ID);

    UOP(sdRing(p - saturnPos), RING_ID);


    return res;
}

#define MAX_DIST 20.0
#define MIN_DIST 0.001
#define MAX_STEPS 200
vec2
RayMarch(vec3 ro, vec3 rd)
{
    float t = 0.0;
    vec2 res = vec2(-1.0, -1.0);

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        vec2 hit = Map(ro + t*rd);

        if(abs(hit.x) < t* MIN_DIST)
        {
            res = vec2(t, hit.y);
            break;
        }

        t+= hit.x;
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

vec3
Material(float id, vec3 pos)
{
    vec3 col = vec3(1.0);

    if(id == SATURN_ID )
    {
        col = vec3(0.875, 0.7, 0.097);
    }

    if(id == MOON_ID )
    {
        col = vec3(0.875, 0.7, 0.097) * 0.24;
    }

    return col;
}

float
CalcShadow(vec3 ro, vec3 rd)
{
    float k = 256.0;
    float n = 1.0;

    for(float t = 0.10; t < MAX_DIST;)
    {
        float h = Map(ro + t*rd).x;

        if(h < MIN_DIST)
        {
            return 0.0;
        }

        n = min(n, k*h/t);

        t += h;
    }
    return n;
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col = vec3(0.0);

    vec2 res = RayMarch(ro, rd);
    float t = res.x;
    float id = res.y;

    //Sky

    //Opaque
    if(id >= 0.0)
    {
        //Geometry
        vec3 P = ro + t*rd;
        vec3 N = CalcNormal(P);

        //Material
        col = Material(id, P);
        //col = vec3(1.0);

        //Lighting
        vec3 lin = vec3(0.0);
        //vec3 L = normalize(vec3(-0.7, 0.1, -0.3));
        vec3 L = normalize(vec3(0.6, 0.5, 0.5));
        //vec3 L = normalize(vec3(-0.6, 0.2, -0.1));
        float diff = saturate(dot(L, N));
        float amb = 0.05;

        //Shadowing
        diff *= CalcShadow(P, L);

        //Shading
        float isRing =  (id == RING_ID) ? 0.0 : 1.0;
        lin += 0.04 * amb  * vec3(1.0) * isRing;
        lin += 1.0 * diff * vec3(1.0, 1.0, 1.0);
        //lin += N;
        col *= lin;
    }
    //Volumetric
    
    return saturate(col);
}

#define AA 2
void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    float nearP = 1.8;
    float roll = 0.001;
    vec3 tot = vec3(0.0);

#if AA > 1
    for(int i =0; i < AA; ++i)
    for(int j =0; j < AA; ++j)
    {
        vec2 offset = 0.5 - vec2(i, j)/ float(AA);
        vec2 uv = ((fragPos + offset) - 0.5*iResolution.xy)/iResolution.y;
#else
        vec2 uv = ((fragPos) - 0.5*iResolution.xy)/iResolution.y;
#endif

#if 0
        vec3 ta = vec3(0.0, -0.025, 0.0);
        vec3 ro = ta + vec3(0.0, 0.0, -1.0);
#else
        //vec3 ta = vec3(0.0, -0.025, 0.0);
        _temp = vec3(0.0, -0.00, 0.0);
        vec3 ta = _temp;
        vec3 ro = ta + vec3(0.0, 2.8, -4.0);
#endif
        mat3 cam = SetCamera(ro, ta, roll);

        vec3 rd = cam * normalize(vec3(uv, nearP));

        vec3 col = Render(ro, rd);

        GAMMA(col);
        tot += col;
#if AA > 1
    }
    tot /= float(AA*AA);
#endif

    fragColor = vec4(tot, 1.0);
}