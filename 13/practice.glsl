//Practice session 0: 04/21/20
//Practice session 1: 04/22/20
//Practice session 2: 04/23/20 (15m)
//Practice session 3: 04/26/20

#include "./hashes.glsl"

float
SmoothNoise(vec2 uv)
{
    vec2 id = floor(uv);
    vec2 fr = fract(uv);

    fr = fr*fr*(3.0 - 2.0*fr);

    float bl = hash12(id);
    float br = hash12(id + vec2(1.0, 0.0));
    float b  = mix(bl, br, fr.x);

    float tl = hash12(id + vec2(0.0, 1.0));
    float tr = hash12(id + vec2(1.0, 1.0));
    float t  = mix(tl, tr, fr.x);

    return mix(b, t, fr.y);
}

float
ValueNoise(vec2 uv, int octaves)
{
    float noise;
    float totalAmplitude;
    float amplitude = 1.0;
    float frequency = 1.0;

    for(int i = 0; i < octaves; ++i)
    {
        totalAmplitude += amplitude;
        noise += SmoothNoise(uv * frequency) * amplitude;
        frequency *= 2.0;
        amplitude /= 2.0;
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

#define HI_LOD 8.0
#define LO_LOD 2.0
float
terrain(vec3 p)
{
    return p.y - ValueNoise(p.xz, 8);
}

#define MAX_STEPS 2000
#define MAX_DIST 200.0
#define MIN_DIST 0.001
float
intersectTerrain(vec3 ro, vec3 rd)
{
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++ i)
    {
        float hit = terrain(ro + t*rd);

        if(abs(hit) < MIN_DIST *t)break;

        t += hit;
    }
    return t;
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col;

    float t = intersectTerrain(ro, rd);
    col += t / 9.80665; // :) 
    col *= vec3(0.78, 0.9, 1.0);

    return saturate(col);
}

#define INV_GAMMA 0.45454545
#define ONE(val) (val * 0.5 - 0.5)
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float nearp = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0 + iTime, 0.0, 0.0);
    vec3 ro = ta + vec3(0.0, 2.0 + 1.2*ONE(sin(iTime / 3.0)) , -abs(10.0*sin(iTime / 15.0)));
    vec2 uv = ((fragCoord) - 0.5*iResolution.xy)/iResolution.y;
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearp));

    vec3 col = Render(ro, rd);
    //col = vec3(hash12(uv));
    //col = vec3(SmoothNoise(uv * 20.0));
    //col = vec3(ValueNoise(uv* 2.0 + iTime, 8));

    //col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}