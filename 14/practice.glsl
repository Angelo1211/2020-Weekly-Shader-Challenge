//Practice 0: 28/04/20 (18m)
//Practice 1: 29/04/20 (18m)
//Practice 2: 30/04/20 (23m)
//Practice 3: 02/05/20
//Practice 4: 03/05/20
//Practice 5: 04/05/20
//Practice 6: 05/05/20
//Practice 7: 06/05/20

#iChannel0 "./textures/mediumNoise.png"
#include "./hashes.glsl"

#define USE_NOISE_TEXTURES 1
vec3
dNoise2D(vec2 uv)
{
    vec2 id = floor(uv);
    vec2 fr = fract(uv);
    ivec2 intId = ivec2(id);

    vec2 interp = fr * fr * (3.0 - 2.0*fr);
    vec2 dInterp = 6.0*fr*(1.0 - fr);

    float bl = 0.0;
    float br = 0.0;
    float tl = 0.0;
    float tr = 0.0;

#if USE_NOISE_TEXTURES
    bl = texelFetch(iChannel0, (intId + ivec2(0, 0))&255, 0).x;
    br = texelFetch(iChannel0, (intId + ivec2(1, 0))&255, 0).x;
    tl = texelFetch(iChannel0, (intId + ivec2(0, 1))&255, 0).x;
    tr = texelFetch(iChannel0, (intId + ivec2(1, 1))&255, 0).x;
#else
    bl = hash12(id + vec2(0.0, 0.0));
    br = hash12(id + vec2(1.0, 0.0));
    tl = hash12(id + vec2(0.0, 1.0));
    tr = hash12(id + vec2(1.0, 1.0));
#endif

    float b = mix(bl, br, interp.x);
    float t = mix(tl, tr, interp.x);

    float noise = mix(b, t, interp.y);

    vec2 derivatives = dInterp *(vec2(br - bl, tl -bl) + (bl -br -tl + tr) * interp.yx);

    return vec3(noise, derivatives);
}

#define TERRAIN_HEIGHT 8.0
#define TERRAIN_FREQUENCY 0.1
vec3
dFBMNoise(vec2 uv, int octaves )
{
    const mat2 layerRotation = mat2(0.8, -0.6, 0.6, 0.8);
    vec2 x = uv * TERRAIN_FREQUENCY ;
    float noise = 0.0;
    float amplitude = 1.0;
    const float frequency = 2.0;
    vec2 derivatives = vec2(0.0);
    for(int i = 0; i < octaves;++i)
    {
        vec3 res = dNoise2D(x);
        derivatives +=res.yz;
        noise += amplitude * res.x / (1.0 + dot(derivatives, derivatives));
        amplitude *= 0.5;
        x = layerRotation * x * frequency;
    }

    return vec3(noise * TERRAIN_HEIGHT, derivatives);
}

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 temp = normalize(vec3(sin(roll), cos(roll), 0.0));

    vec3 k = normalize(target - eye);
    vec3 i = normalize(cross(temp, k));
    vec3 j = cross(k, i);

    return mat3(i, j , k);
}

vec3
terrain(vec3 p, int lod)
{
    return p.y - dFBMNoise(p.xz, lod);
}

#define MAX_STEPS 200
#define MIN_DIST 0.001
#define MAX_DIST 200.0
vec3
intersectTerrain(vec3 ro, vec3 rd)
{
    const int lod = 8;
    vec3 res = vec3(-1.0);
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        vec3 hit = terrain(ro + t*rd, lod);

        if(abs(hit.x) < t*MIN_DIST)
        {
            res = vec3(t, hit.yz);
            break;
        }
        t += 0.4*hit.x;
    }

    return res;
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col = vec3(0.0);

    vec3 res = intersectTerrain(ro, rd);
    float t = res.x;
    if(t < 0.0) return vec3(1.0);
    vec2 dTerrain = res.yz;
    vec3 P = ro + t*rd;
    vec2 norm = terrain(P, 8).yz;
    vec3 N = normalize(vec3(norm.x, 0., norm.y));
    vec3 L = normalize(vec3(1.0, 1.0, 0.0));

    col += saturate(dot(L, N));

    return col;
}

#define INV_GAMMA 0.45454545
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //camera
    float nearp = 0.4;
    float roll = 0.0;
    vec3 ta = vec3(iTime, 0.0, iTime);
    vec3 ro = ta + vec3(0.0, 10.0, -200.0);
    vec2 uv = ((2.0*fragCoord) - iResolution.xy)/iResolution.y;
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam*normalize(vec3(uv, nearp));

    vec3 col = Render(ro, rd);
    //noise tests
    //uv *= 20.0;
    //col = vec3(hash12(uv));//by hash
    //col = vec3(texelFetch(iChannel0, ivec2(fragCoord)&255, 0).x);//by texture
    //col = vec3(dNoise2D(uv).x); //Smooth noise only 
    //col = dNoise2D(uv); //Smooth noise with derivatives 
    //col = vec3(dFBMNoise(uv, 8).x);

    //col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}
