//Practice session 0: 04/21/20
//Practice session 1: 04/22/20
//Practice session 2: 04/23/20 (15m)

#include "./hashes.glsl"

// float
// hash12(vec2 p)
// {
//     return fract(sin(dot(vec2(12.9898, 48.233), p)) * 473072.8);
// }

float
smoothNoise(vec2 uv)
{
    vec2 id = floor(uv); //[3, 2]
    vec2 fr = fract(uv); //[.5, .65]

    fr = fr * fr *(3.0 - 2.0*fr);

    float bl = hash12(id);
    float br = hash12(id + vec2(1.0, 0.0));
    float b = mix(bl, br, fr.x);

    float tl = hash12(id + vec2(0.0, 1.0));
    float tr = hash12(id + vec2(1.0, 1.0));
    float t = mix(tl, tr, fr.x);

    return mix(b, t, fr.y);
}

float
valueNoise(vec2 uv, int octaves)
{
    float noise = 0.0;
    float amplitude = 1.0 + sin(iTime);
    float frequency = 1.0;
    float totalAmplitude = 0.0;

    for(int i = 0; i < octaves; ++i)
    {
        noise += smoothNoise(uv * frequency) * amplitude;
        totalAmplitude += amplitude;
        amplitude /= 2.0;
        frequency *= 2.0;
    }

    return noise / totalAmplitude;
}

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 i, j, k, temp;

    k = normalize(target - eye);
    temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    i = normalize(cross(temp, k));
    j = cross(k, i);
    return mat3(i, j, k);
}

float
terrain(vec3 p, int lod)
{
    return p.y - valueNoise(p.xz, lod);
}

#define MAX_STEPS 2000
#define MAX_DIST 200.0
#define MIN_DIST 0.0001
float
intersectTerrain(vec3 ro, vec3 rd)
{
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        float inter = terrain(ro + t*rd, 8);

        if(abs(inter) < MIN_DIST *t) break;

        t += inter;
    }

    return t;
}

#define TOTAL_LODS 8
#define LOD_RANGE 128.0
vec3 cols[8] = vec3[8](vec3(0.0, 0.0, 1.0),
                       vec3(0.0, 1.0, 0.0),
                       vec3(0.0, 1.0, 1.0),
                       vec3(1.0, 0.0, 0.0),
                       vec3(1.0, 0.0, 1.0),
                       vec3(1.0, 1.0, 0.0),
                       vec3(1.0, 1.0, 1.0),
                       vec3(0.0, 0.0, 0.0));

vec3
CalcNormal(vec3 p, float t)
{
    vec2 e = vec2(0.0001, 0.0);
    int lod = max(TOTAL_LODS - int(((t / MAX_DIST))*LOD_RANGE), 1);
    return normalize(vec3(terrain(p + e.xyy, lod) - terrain(p - e.xyy, lod),
                          terrain(p + e.yxy, lod) - terrain(p - e.yxy, lod),
                          terrain(p + e.yyx, lod) - terrain(p - e.yyx, lod)
    ));
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col;

    vec3 sky = vec3(0.4, .7, .9);
    col = sky;
    float t;

    if(dot(rd, vec3(0., 1. , 0.0)) < 0.0)
    {
        //Ray itersection
        t = intersectTerrain(ro, rd);
        //Geometry
        vec3 P = ro + t*rd;
        vec3 N = CalcNormal(P, t);

        //Material
        col = vec3(0.7, 0.7, 0.4);

        if(P.y > 0.8)
            col = vec3(1.0);
        
        //Lighting
        vec3 L = normalize(vec3(1.0, 1.0, 0.0));
        float diffuse = saturate(dot(N, L));
        vec3 lin = vec3(0.0);
        float amb = 0.06;

        lin += diffuse;
        lin += amb * sky * 9.00;


        col *= lin;

        int lod = max(TOTAL_LODS - int(((t / MAX_DIST))*LOD_RANGE), 1);
        //col += cols[int(((t / MAX_DIST))*32.0)];

        if(P.y < 0.3)
            col = sky;
    }

    col = mix(col, sky, 1.0 -exp(-0.009*t*t));
    return saturate(col);
}

#define INV_GAMMA 0.454545
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{

    //Camera
    float nearP = 1.0;
    float roll = 0.0;

    vec3 ta = vec3(iTime, 0.0, iTime);
    vec3 ro = ta + vec3(0.0, 2.0, -10.0);
    mat3 cam = SetCamera(ro, ta, roll);
    vec2 uv = ((fragCoord) - 0.5*iResolution.xy)/ iResolution.y;
    vec3 rd = cam * normalize(vec3(uv, nearP));

    vec3 col; 
    col = Render(ro, rd);
    //col += hash12(uv*20.0);
    //col += smoothNoise(uv*20.0);
    //col += valueNoise(uv*3.4+ iTime, 10);

    //col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}