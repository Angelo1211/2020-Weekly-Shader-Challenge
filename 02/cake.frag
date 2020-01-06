/*
    Sunday Shader: 2/52 " "
    Intro blurb
*/

/*Game Plan:
    Todo
    - [ ] UV coordinate color top
    - [ ] Something to raise the cake so It ain't on the ground
    - [ ] Wood floring
    - [ ] Raspberries 
    - [ ] Add cake shape

    In Progress
    - [ ] 

    Done
    - [x] Basic SDF Renderer

    Nice To Haves
    - [ ] 
*/
#define INV_GAMMA 0.454545
#define MAX_DIST 200.0
#define MIN_DIST 0.001
#define MAX_STEPS 400
#define AA 4

#define GROUND_ID 0.0
#define SPHERE_ID 1.0

float
sdSphere(vec3 normDist, float r)
{
    return length(normDist) - r;
}

float
sdGround(vec3 p)
{
    return p.y;
}

vec2
uop(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);
    res = uop(res, vec2(sdGround(p + 0.25), GROUND_ID));
    res = uop(res, vec2(sdSphere(p - vec3(0.0, 0.1*sin(iTime), 0.0), 0.25), SPHERE_ID)); 

    return res;
}

vec2
Raymarch(vec3 ro, vec3 rd)
{
    vec2 res = vec2(1e10, -1.0);
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; i++)
    {
        vec2 hit = Map(ro + t*rd);

        if(abs(hit.x) < t * MIN_DIST)
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

float
CalcSoftShadows(vec3 ro, vec3 rd)
{
    float k = 2.0;
    float res = 1.0;
    for(float t = 0.05; t < MAX_DIST;)
    {
        float h = Map(ro + t*rd).x;

        if(h < MIN_DIST)
        {
            return 0.0;
        }
        res = min(res, h *k / t);
        t +=h;
    }
    return res;
}


vec3
Render(vec3 ro, vec3 rd, vec2 uv)
{
    //Ray setup
    vec3 col = vec3(0.0);
    vec2 res = Raymarch(ro, rd);
    float id = res.y;
    float t = res.x;

    //Sky
    vec3 sky = vec3(0.0, 0.3, 1.0);
    col =  sky * rd.y;

    //Solids
    if (id >= 0.0)
    {
        //Geometry
        vec3 P = ro + t*rd;
        vec3 N = CalcNormal(P);
        vec3 R = reflect(rd, N);

        //Material
        col = vec3(1.0);
        if(id == 0.0)
        {
            vec2 tileID = floor(P.xz * 5.0);
            float isEven = mod(tileID.x + tileID.y, 2.0); 
            col = vec3(0.15)*isEven + vec3(0.1);
        }

        //Lighting
        vec3 L = normalize(vec3(1.0, 1.0, 0.0));
        vec3 H = normalize(L-rd);
        vec3 lin = vec3(0.0);
        float diff = saturate(dot(L, N));
        float spec = pow(max(dot(N, H), 0.0), 256.0);
        float ambi = 0.022;
        float fres = pow(1.0 + dot(N,rd), 4.0);

        //Shadowing
        diff *= CalcSoftShadows(P, L);

        //Shading
        lin += 1.00 * diff * vec3(1.0, 1.0, 1.0);
        lin += 1.00 * ambi  * sky;
        lin += 1.00 * spec * vec3(1.0);
        lin += 0.05 * fres * vec3(1.0);

        col *= lin;
    }

    //Volumetrics

    col = mix(col, sky, 1.0 - exp(-0.009 *t *t));

    return saturate(col);
}

mat3
SetCamera(vec3 eye, vec3 tar, float roll)
{
    vec3 f, r, u;
    f = normalize(tar - eye);
    vec3 upRoll = normalize(vec3(sin(roll), cos(roll), 0.0));
    r = normalize(cross(upRoll, f));
    u = cross(f, r);

    return mat3(r, u, f);
}


void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    //General controls
    vec3 tot = vec3(0.0);
    float radius = 1.0; 
    float time = iTime / 5.0;

    //Camera setup
    float nearP = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0, 0.0, 0.0);
#if 1
    vec3 ro = ta + vec3(radius * sin(time), 0.0, radius*cos(time));
#else
    vec3 ro = ta + vec3(0.0, 0.0, -radius);
#endif
    mat3 cam = SetCamera(ro, ta, roll);
#if AA > 1
    for(int i =0; i < AA; ++i)
    for(int j =0; j < AA; ++j)
    {
        vec2 offset = vec2(i, j) / float(AA) - 0.5;
        vec2 uv = ((fragPos + offset) - 0.5*iResolution.xy)/iResolution.y;
#else
        vec2 uv = ((fragPos) - 0.5*iResolution.xy)/iResolution.y;
#endif
        vec3 rd = cam * normalize(vec3(uv, nearP));

        //Rendering
        vec3 col = Render(ro, rd, uv);

        //Gamma correction
        col = pow(col, vec3(INV_GAMMA));

        tot += col;
#if AA > 1
    }
    tot /= float(AA*AA); 
#endif

    fragColor = vec4(tot, 1.0);
}