//Practice 0: 28/04/20 (18m)
//Practice 1: 29/04/20 (18m)
//Practice 2: 30/04/20 (23m)
//Practice 3: 02/05/20
//Practice 4: 03/05/20
//Practice 5: 04/05/20
//Practice 6: 05/05/20
//Practice 7: 06/05/20
//Practice 8: 10/05/20

#include "./hashes.glsl"
#iChannel0 "./textures/mediumNoise.png"
#define USE_NOISE_TEXTURE 0

vec3
dNoise2D(vec2 uv)
{
    vec2 id = floor(uv);
    ivec2 iId = ivec2(id);
    vec2 fr = fract(uv);

    vec2 interp = fr*fr*(3.0 - 2.0*fr);
    vec2 dInterp = 6.0*fr*(1.0 - fr);

    float bl, br, tl, tr;
#if USE_NOISE_TEXTURE 
    bl = texelFetch(iChannel0, (iId + ivec2(0, 0))&255, 0).x;
    br = texelFetch(iChannel0, (iId + ivec2(1, 0))&255, 0).x;

    tl = texelFetch(iChannel0, (iId + ivec2(0, 1))&255, 0).x;
    tr = texelFetch(iChannel0, (iId + ivec2(1, 1))&255, 0).x;
#else
    bl = hash12(id + vec2(0.0, 0.0));
    br = hash12(id + vec2(1.0, 0.0));
    tl = hash12(id + vec2(0.0, 1.0));
    tr = hash12(id + vec2(1.0, 1.0));
#endif
    float b = mix(bl, br, interp.x);
    float t = mix(tl, tr, interp.x);

    float noise = mix(b, t, interp.y);

    vec2 derivatives = dInterp*(vec2(br - bl,tl -bl) + (bl - br - tl + tr)* interp.yx);

    return vec3(noise, derivatives);
}

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 temp = normalize(vec3(sin(roll), cos(roll), 0.0));

    vec3 k = normalize(target -eye);
    vec3 i = normalize(cross(temp, k));
    vec3 j = cross(k, i);

    return mat3(i,j,k);
}

const mat2 rotationMatrix = mat2(0.8, -0.6, 0.6, 0.8);

#define TERRAIN_HEIGHT 250.0
#define TERRAIN_FREQUENCY 0.15;
float
dValueNoise(vec2 uv, int octaves)
{
    vec2 x = uv * 0.03* TERRAIN_FREQUENCY;
    float noise = 0.0;
    float amplitude = 1.0;
    float frequency = 2.0;
    vec2 derivatives = vec2(0.0);
    float erosion = 1.0;

    for(int i = 0; i < octaves; ++i)
    {
        vec3 res = dNoise2D(x);
        derivatives += res.yz;
        noise += (res.x * amplitude) / (1.0 + erosion*dot(derivatives, derivatives)); 
        amplitude *= 0.5;
        x = rotationMatrix * x * frequency;
    }

    return noise * TERRAIN_HEIGHT;
}

float
terrain(vec3 p, int lod)
{
    return p.y - dValueNoise(p.xz, lod);
}


#define MAX_DIST 200.0
#define MIN_DIST 0.001
#define MAX_STEPS 200
float
intersectTerrain(vec3 ro, vec3 rd)
{
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        const int lod = 10;
        float h = terrain(ro + t*rd, lod);

        if(abs(h) < t*MIN_DIST) break;

        t += 0.3*h; //Sphere march but take only 40% of the largest possible step
    }

    return t;
}

vec3
CalcNormal(vec3 p)
{
    vec2 e = vec2(0.001, 0.0);
    const int lod = 8;
    return normalize(vec3(terrain(p + e.xyy, lod) - terrain(p - e.xyy, lod), 
                          terrain(p + e.yxy, lod) - terrain(p - e.yxy, lod),
                          terrain(p + e.yyx, lod) - terrain(p - e.yyx, lod)));
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col = vec3(0.0);

    {
        float t = intersectTerrain(ro, rd);
        vec3 P = ro + t*rd;
        vec3 N = CalcNormal(P);
        vec3 L = normalize(vec3(1.0, 1.0, 0.0));
        float diff = saturate(dot(N, L));
        col = 1.0 * diff * vec3(0.9, 0.8, 1.0); 
    }


    return col;
}

#define INV_GAMMA 0.454545454
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Camera setup
    float nearp = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0, 0.0, 0.0 + iTime);
    vec3 ro = ta + vec3(0.0, 4.0, -10.0);
    vec2 uv = (2.0*(fragCoord) - iResolution.xy)/iResolution.y;
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearp));

    vec3 col = Render(ro, rd);
    //Noise testing
    //uv *= 20.0;
    //col = vec3(hash12(uv)); //Hash based noise
    //col = vec3(texelFetch(iChannel0, ivec2(fragCoord)&255, 0).x);//texture based noise 
    //col = vec3(dNoise2D(uv).x); //Value noise 
    //col = vec3(dNoise2D(uv)); //Value noise w/ derivatives

    col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}
