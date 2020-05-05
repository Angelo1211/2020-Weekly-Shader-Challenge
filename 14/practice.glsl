//Practice 0: 28/04/20 (18m)
//Practice 1: 29/04/20 (18m)
//Practice 2: 30/04/20 (23m)
//Practice 3: 02/05/20
//Practice 4: 03/05/20
//Practice 5: 04/05/20
//Practice 5: 05/05/20

#iChannel0 "./textures/mediumNoise.png"
#include "./hashes.glsl"

#define USE_NOISE_TEXTURE 0
vec3
dNoise2D(vec2 uv)
{
    vec2 id = floor(uv);
    ivec2 i_id = ivec2(id);
    vec2 fr = fract(uv);

    vec2 interp = fr*fr*(3.0 - 2.0*fr);
    vec2 dInterp = 6.0*fr*(1.0 - fr);
    
    float bl = 0.0;
    float br = 0.0;
    float tl = 0.0;
    float tr = 0.0;

#if USE_NOISE_TEXTURE
    bl = texelFetch(iChannel0, i_id + ivec2(0, 0)&255, 0).x;
    br = texelFetch(iChannel0, i_id + ivec2(1, 0)&255, 0).x;

    tl = texelFetch(iChannel0, i_id + ivec2(0, 1)&255, 0).x;
    tr = texelFetch(iChannel0, i_id + ivec2(1, 1)&255, 0).x;
#else 
    bl = hash12(id + vec2(0.0, 0.0));
    br = hash12(id + vec2(1.0, 0.0));

    tl = hash12(id + vec2(0.0, 1.0));
    tr = hash12(id + vec2(1.0, 1.0));
#endif

    float b = mix(bl, br, interp.x);
    float t = mix(tl, tr, interp.x);

    float noise = mix(b, t, interp.y);
    vec2 derivatives = dInterp * (vec2(br - bl, tl - bl) + (bl - br - tl +tr) * interp.yx);

    return vec3(noise, derivatives);
}

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    vec3 k = normalize(target - eye);
    vec3 i = normalize(cross(temp, k));
    vec3 j = cross(k , i);
    return mat3(i, j, k);
}

//Rotating the query position at each noise layer
mat2 layerRot = mat2(0.8, -0.6, 0.6, 0.8);

#define TERRAIN_HEIGHT 3.0
#define TERRAIN_FREQUENCY 0.2
vec3
terrainNoise(vec2 uv, int octaves)
{
    vec2 x = uv * TERRAIN_FREQUENCY;
    float noise = 0.0;
    const float frequency = 2.0;
    float amplitude = 1.0;
    vec2 derivatives = vec2(0.0);

    for(int i = 0; i < octaves; ++i)
    {
        vec3 n = dNoise2D(x);
        derivatives += n.yx;
        noise += (n.x * amplitude)/ (1.0 + dot(derivatives, derivatives));
        amplitude *= 0.5;
        x *= layerRot * frequency;
    }   

    return vec3(noise * TERRAIN_HEIGHT, derivatives);
}

vec3
terrain(vec3 p)
{
    int lod = 8;
    vec3 terrainWDerivatives = vec3(p.y, vec2(0.0));
    return terrainWDerivatives + terrainNoise(p.xz, lod);
}

#define MAX_STEPS 200
#define MAX_DIST 200.0
#define MIN_DIST 0.001
vec3
RaymarchTerrain(vec3 ro, vec3 rd)
{
    float t = 0.0;
    vec2 normals = vec2(0.0);

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        vec3 h = terrain(ro + rd*t);

        if(abs(h.x) < t * MIN_DIST)
        {
            normals = h.yz;
            break;
        } 

        t += 0.4*h.x;
    }

    return vec3(t, normals);
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col = vec3(0.0);

    vec3 res = RaymarchTerrain(ro, rd);
    float t = res.x;

    vec3 P = ro + t*rd;
    vec3 N = normalize(vec3(-res.y, 1.0 , -res.z));
    vec3 L = normalize(vec3(1.0, 1.0, 0.0));

    float diff = saturate(dot(N, L));

    col += diff * vec3(1.0, 1.0, 1.0);

    return (col);
}

#define INV_GAMMA 0.454545
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Camera setup
    float nearp = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0, 0.0, 0.0);
    vec3 ro = ta + vec3(0.0, 2.0, -10.0);
    vec2 uv = ((fragCoord) - 0.5*iResolution.xy)/iResolution.y;
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam*normalize(vec3(uv, nearp));

    vec3 col = Render(ro, rd);
    //Testing noise
    //col = vec3(texelFetch(iChannel0, ivec2(fragCoord)&255, 0)); //texture
    //col = vec3(hash12(uv)); //hash based noise
    //col = vec3(dNoise2D(uv* 20.0).x); //Filtered noise 
    //col = vec3(dNoise2D(uv * 20.0)); //Filtered noise  with derivatives

    //col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}
