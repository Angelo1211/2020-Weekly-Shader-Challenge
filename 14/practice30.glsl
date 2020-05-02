//Practice 0: 28/04/20 (18m)
//Practice 1: 29/04/20 (18m)
//Practice 2: 30/04/20 (23m)

#include "./hashes.glsl"

//Bilinearly filtered noise with derivatives
vec3
biNoiseD(vec2 uv)
{
    vec2 id = floor(uv);
    vec2 fr = fract(uv);

    //Cubic interpolation
    vec2 interp = fr * fr * (3.0 - 2.0*fr); 

    //Cubic interp derivative
    vec2 interpD = 6.0*fr*(1.0 - fr);

    //Bottom
    float bl = hash12(id + vec2(0.0, 0.0));
    float br = hash12(id + vec2(1.0, 0.0));
    float b  = mix(bl, br, interp.x);

    //Top
    float tl = hash12(id + vec2(0.0, 1.0));
    float tr = hash12(id + vec2(1.0, 1.0));
    float t  = mix(tl, tr, interp.x);

    //Bilinearly filtered noise result
    float smoothNoise = mix(b , t, interp.y);

    //Derivative calc
    //TODO
    vec2 noiseD = interpD * vec2(0.0);

    return vec3(smoothNoise, noiseD);
}

float
valueNoise(vec2 uv, int octaves)
{
    float amplitude = 1.0;
    float noise = 0.0;
    float frequency = 1.0;
    float totalAmplitude = 0.0;

    for(int i = 0; i < octaves; ++i)
    {
        noise += biNoiseD(uv * frequency).x * amplitude;
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
    temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    k = normalize(target - eye);
    i = normalize(cross(temp, k));
    j = cross(k , i);

    return mat3(i, j, k);
}

float
terrain(vec3 p)
{
    int lod = 8;
    return p.y - valueNoise(p.xz, lod);
}

#define MAX_DIST 20.0
#define MAX_STEPS 200
#define MIN_DIST 0.001
float
intersectTerrain(vec3 ro, vec3 rd)
{
    float t = 0.0;
    
    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        float h = terrain(ro + rd*t);

        if(abs(h) < t*MIN_DIST) break;

        t += 0.5*h;
    }

    return t;
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col = vec3(0.0);
    //Raymarching the terrain
    float t = intersectTerrain(ro, rd);

    col = vec3(t / 10.0);

    return col;
}

#define INV_GAMMA 0.454545  
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Camera setup
    float nearp = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0 + iTime, 0.0, 0.0);
    vec3 ro = ta + vec3(0.0, 2.0, -10.0);
    vec2 uv = ((fragCoord) - 0.5*iResolution.xy)/ iResolution.y;
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearp));

    vec3 col = Render(ro, rd);

    //Noise testing
    //col = vec3(hash12(uv));
    //col = vec3(biNoiseD(uv* 20.0).x);
    //col = vec3(biNoiseD(uv* 20.0).yz, 0.0);
    //col = vec3(valueNoise(uv * 2.0 + iTime, 8));

    //col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}