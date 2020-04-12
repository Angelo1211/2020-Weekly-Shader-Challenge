#include "./common.glsl"

float
hash(vec2 n){
    return fract(sin(dot(n,vec2(12.9898, 4.1414)))*43758.5453);
}

#define SATURN_ID 0.0
#define GROUND_ID 1.0 
vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    UOP(sdSphere(p - vec3(0.0, 1.0, 0.0), 0.85), SATURN_ID);
    UOP(sdGroundPlane(p), GROUND_ID);
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


    return col;
}

float
CalcShadow(vec3 ro, vec3 rd)
{
    float k = 2.0;
    float res = 1.0;

    for(float t = 0.10; t < MAX_DIST;)
    {
        float h = Map(ro + t*rd).x;
        res = min(res, h*k / t);

        if(h < MIN_DIST)
            return 0.0;
        t += h;
    }
    return res; 
}

vec3
Render(vec3 ro, vec3 rd, vec2 uv)
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

        //Lighting
        vec3 lin = vec3(0.0);
        float ang = M_PI;// + iTime / 10.0 ;
        vec3 L = normalize(vec3(cos(ang), 0.5, sin(ang)));
        float diff = saturate(dot(L, N));
        float amb = 0.05;

        //Shadowing
        diff *= CalcShadow(P, L);

        //Shading
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
        //Camera
        vec3 ta  = vec3(0.0, 0.00, 0.0);
        vec3 ro  = ta + vec3(1.0, 0.0, -5.5);
        mat3 cam = SetCamera(ro, ta, roll);
        vec3 rd  = cam * normalize(vec3(uv, nearP));
        vec3 col = Render(ro, rd, uv);
        col = rd;
        //https://www.3dgep.com/understanding-the-view-matrix/#Look_At_Camera
        //col *= vec3(1, 0, 0); //Red only
        //col *= vec3(0, 1, 0); //Green only
        //col *= vec3(0, 0, 1); //Blue only

        GAMMA(col);
        tot += col;
#if AA > 1
    }
    tot /= float(AA*AA);
#endif

    fragColor = vec4(tot, 1.0);
}