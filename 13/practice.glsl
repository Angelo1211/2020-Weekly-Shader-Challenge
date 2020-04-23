//Practice sesion 0: 04/21/20
//Practice sesion 1: 04/22/20
//Practice sesion 2: 04/23/20 (15m)

#include "./hashes.glsl"

// float
// hash12(vec2 p )
// {
// 	vec3 p3  = fract(vec3(p.xyx) * .1031);
//     p3 += dot(p3, p3.yzx + 33.33);
//     return fract((p3.x + p3.y) * p3.z);
// }

float
SmoothNoise(vec2 uv)
{
    vec2 id = floor(uv);
    vec2 fr = fract(uv);

    fr = fr*fr*(3.0 - 2.0*fr);

    float bl = hash12(id);
    float br = hash12(id + vec2(1.0, 0.0));
    float b = mix(bl, br, fr.x);

    float tl = hash12(id + vec2(0.0, 1.0));
    float tr = hash12(id + vec2(1.0, 1.0));
    float t = mix(tl, tr, fr.x);

    return mix(b,t, fr.y);
}

float
valueNoise(vec2 uv, int octaves)
{
    float noise = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float totalAmplitude = 0.0;

    for(int octave = 0; octave < octaves; ++octave)
    {
        noise += amplitude*SmoothNoise(uv *frequency);
        totalAmplitude += amplitude;
        amplitude /= 2.0;
        frequency *= 2.0;
    }
    totalAmplitude += amplitude;
    return noise / totalAmplitude;

}

#define TERRAIN_HEIGHT 1.5
float
terrain(vec3 p, int octaves)
{
    return p.y - valueNoise(p.xz, octaves)* TERRAIN_HEIGHT;
}

#define MAX_DIST 200.0
#define MIN_DIST 0.0001
#define MAX_STEPS 2000
float
intersectTerrain(vec3 ro, vec3 rd)
{
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        float h = terrain(ro + t*rd, 8);

        if(abs(h) < MIN_DIST * t) break;

        t += 0.3*h; 
    }

     return t;
}

vec3
CalcNormal(vec3 p)
{
    vec2 e = vec2(0.0001, 0.0);
    const int lowLOD = 8;

    return normalize(vec3(terrain(p + e.xyy, lowLOD) - terrain(p - e.xyy, lowLOD),
                          terrain(p + e.yxy, lowLOD) - terrain(p - e.yxy, lowLOD),
                          terrain(p + e.yyx, lowLOD) - terrain(p - e.yyx, lowLOD) 
                          ));
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col;

    //if(dot(rd, vec3(0.0, 1.0,0.0)) > 0.0) return col; 

    float t = intersectTerrain(ro, rd);

    vec3 P = ro + t*rd;
    vec3 N = CalcNormal(P);
    vec3 L = normalize(vec3(1.0, 1.0, 0.0));

    float diff = saturate(dot(N,L));

    col += diff;

    //col += N;



    return saturate(col);
}

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 i, j , k, temp;
    k = normalize(target - eye);
    temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    i = normalize(cross(temp, k));
    j = cross(k, i);
    return mat3(i, j ,k);
}

#define INV_GAMMA 0.454545
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float nearp = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0);
    vec3 ro = ta + vec3(0.0, 0.4, -10.0);
    vec2 uv = ((fragCoord) - 0.5*iResolution.xy) / iResolution.y;
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearp));
    
    vec3 col = Render(ro, rd);
    //col += SmoothNoise(uv * 16.0);
    //col += valueNoise(uv, 16);

    col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}