//Practice 0: 28/04/20 (18m)
//Practice 1: 29/04/20 (18m)
//Practice 2: 30/04/20 (23m)
//Practice 3: 02/05/20
//Practice 4: 03/05/20

#include "./hashes.glsl"
#iChannel0 "./textures/mediumNoise.png"

//Value noise with analytical derivatives
vec3
dNoise2D(vec2 uv)
{
    ivec2 id = ivec2(floor(uv));
    vec2 fr = fract(uv);

    //cubic interpolation
    vec2 interp = fr*fr*(3.0 - 2.0*fr);
    vec2 dInterp = 6.0*fr*(1.0 - fr); //dx

    //Clamp to edge kinda?
    const int q = 255;
    float bl = texelFetch(iChannel0, (id + ivec2(0, 0))&q, 0).x; //a
    float br = texelFetch(iChannel0, (id + ivec2(1, 0))&q, 0).x; //b
    float b = mix(bl, br, interp.x);

    float tl = texelFetch(iChannel0, (id + ivec2(0, 1))&q, 0).x; //c
    float tr = texelFetch(iChannel0, (id + ivec2(1, 1))&q, 0).x; //d
    float t = mix(tl, tr, interp.x);

    //bilinear interpolation
    float noise = mix(b, t, interp.y);

    //checkout included pdf for where this comes from:
    vec2 dNoise = dInterp * (vec2(-bl + br, -bl + tl) + (bl - br - tl + tr) * interp.yx  );
    return vec3(noise, dNoise);
}

float
valueNoise(vec2 uv, int octaves)
{
    float noise;
    float totalAmplitude;
    float amplitude = 1.0;
    float frequency = 1.0;

    for(int i = 0; i < octaves; ++i)
    {
        noise += amplitude*dNoise2D(uv*frequency).x;
        totalAmplitude += amplitude;
        frequency *= 2.0;
        amplitude /= 2.0;
    }

    return noise / totalAmplitude;
}

float
terrain(vec3 p)
{
    return p.y - valueNoise(p.xz, 8);
}

#define MAX_STEPS 2000
#define MIN_DIST 0.001
#define MAX_DIST 200.0
float
intersectTerrain(vec3 ro, vec3 rd)
{
    float t = 0.0;

    for(int i =0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        float h = terrain(ro + rd*t);
        if(abs(h) < t*MIN_DIST) break;
        t +=h;
    }


    return t;
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col;

    float t = intersectTerrain(ro, rd);

    col += t / 10.0;

    return col;
}

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 temp, i, j, k;

    temp = normalize(vec3(sin(roll), cos(roll), 0.0));

    k = normalize(target - eye);
    i = normalize(cross(temp, k));
    j = cross(k, i);

    return mat3(i, j, k);
}

#define INV_GAMMA 0.454545
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Camera
    float nearp = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0 + iTime, 0.0, 0.0);
    vec3 ro = ta + vec3(0.0, 2.0, -10.0);
    vec2 uv = ((fragCoord) - 0.5*iResolution.xy)/ iResolution.y;
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearp));
    
    vec3 col = Render(ro, rd);
    //Noise test
    //col = vec3(hash12(uv));
    //col = vec3(noise2D_D(uv*20.0).x);  // just the noise
    //col = (dNoise2D(uv*20.0));  // the derivatives

    //col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}
