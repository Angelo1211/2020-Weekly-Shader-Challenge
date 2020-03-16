#include "./common.glsl"

float
hash(vec2 n){
    return fract(sin(dot(n,vec2(12.9898, 4.1414)))*43758.5453);
}

float
sdRing(vec3 p)
{
    vec3 pos = p - vec3(-0., -0.00, 0.0);

    float r = length(vec2(pos.x, pos.z));
    float ringSize = 2.0;
    float d = sdBox(pos, vec3(ringSize, 0.00002, ringSize));
    if(r > ringSize || r < 1.35) d += 0.001;
    if(r > 1.75 && r < ringSize - 0.18)  d += 0.001;
    if(r > 1.975 && r < ringSize - 0.02)  d += 0.001;

    return d;
}

#define SATURN_ID 0.0
#define MOON_ID 1.0
#define RING_ID 2.0
vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    UOP(sdSphere(p, 0.85), SATURN_ID);
    UOP(sdRing(p), RING_ID);

    float ang = -iTime/ 12.0 + M_PI;
    float rad = 1.5;
    UOP(sdSphere(p - vec3(rad*sin(ang), 0.2, rad*cos(ang)), 0.05), MOON_ID);

    return res;
}

#define MAX_DIST 20.0
#define MIN_DIST 0.0001
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
        vec2 uv = vec2(atan(pos.x, pos.z) / (2.0*M_PI) + 0.5, pos.y *0.5 + 0.5);
        col = vec3(0.789, 0.765, 0.43);
        if(uv.y > 0.91) col *= 0.95;
    }

    if(id == RING_ID )
    {
        float r = length(pos.xz);
        r -= 1.0;
        r = 1.0 - r;
        col = mix(vec3(0.875, 0.7, 0.097) * 0.2, vec3(0.875, 0.7, 0.5)*1.0, r);
    }

    if(id == MOON_ID) col = vec3(0.25, 0.6, 0.375);

    return col;
}

float
CalcShadow(vec3 ro, vec3 rd)
{
    for(float t = 0.10; t < MAX_DIST;)
    {
        float h = Map(ro + t*rd).x;

        if(h < MIN_DIST)
            return 0.0;
        t += h;
    }
    return 1.0;
}

vec3
Render(vec3 ro, vec3 rd, vec2 uv)
{
    vec3 col = vec3(0.0);
    vec2 res = RayMarch(ro, rd);
    float t = res.x;
    float id = res.y;

    //Sky
    col += vec3(1.0) * pow(hash(uv * vec2(13.0, 2.2)), 703.58);
    col *= 6.0;

    //Opaque
    if(id >= 0.0)
    {
        //Geometry
        vec3 P = ro + t*rd;
        vec3 N = CalcNormal(P);

        //Material
        col = Material(id, P);

        //Lighting
        vec3 lin = vec3(0.0);
        float ang = M_PI / 4.2 + iTime / 25.0 ;
        vec3 L = normalize(vec3(cos(ang), 0.5, sin(ang)));
        float diff = saturate(dot(L, N));
        float amb = 0.05;

        //Shadowing
        diff *= CalcShadow(P, L);

        //Shading
        float isRing =  (id == RING_ID) ? 0.0 : 1.0;
        isRing *= P.y * 6.0;
        lin += 0.07 * amb  * vec3(1.0) * isRing;
        lin += 1.2 * diff * vec3(1.0, 1.0, 1.0);
        col *= lin;
    }
    return saturate(col);
}

#define AA 2
void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    float nearP = 1.8;
    float roll = 0.0;
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

        vec3 ta = vec3(0.0, 0.00, 0.0);
        vec3 ro = ta + vec3(0.0, 1.7, -4.5);
        mat3 cam = SetCamera(ro, ta, roll);
        vec3 rd = cam * normalize(vec3(uv, nearP));
        vec3 col = Render(ro, rd, uv);

        GAMMA(col);
        tot += col;
#if AA > 1
    }
    tot /= float(AA*AA);
#endif

    fragColor = vec4(tot, 1.0);
}