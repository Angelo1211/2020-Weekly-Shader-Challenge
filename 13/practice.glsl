//Practice sesion 0: 04/21/20
//Practice sesion 1: 04/22/20

float
hash(float seed)
{
    uvec2 p = floatBitsToUint(vec2(seed+=.1,seed+=.1));
    p = 1103515245U*((p >> 1U)^(p.yx));
    uint h32 = 1103515245U*((p.x)^(p.y>>3U));
    uint n = h32^(h32 >> 16);
    return float(n)/float(0xffffffffU);
}

float
smoothNoise(vec2 uv)
{
    vec2 id = floor(uv);
    vec2 fr = fract(uv);

    return hash(dot(uv, vec2(12.9898, 78.233)));
}

float
valueNoise(vec2 uv, int octaves)
{
    float noise;

    noise = smoothNoise(uv);

    return noise;
}

float
terrain(vec3 p)
{
    return p.y - valueNoise(p.xz, 8);
}

#define MAX_STEPS 200
#define MAX_DIST 200.0
#define MIN_DIST 0.001
float
intersectTerrain(vec3 ro, vec3 rd)
{
    float t;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        float h = terrain(ro + t*rd);

        if(abs(h) < t*MIN_DIST) break;

        t += h;
    }

    return t;
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col;
    //Terrain Rendering
    float t = intersectTerrain(ro, rd);

    col += t / 100.0;

    return saturate(col);
}

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 i, j, k, temp;
    k = normalize(target - eye);
    temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    i = normalize(cross(temp, k));
    j =           cross(k, i);  
    return mat3(i, j , k);
}

#define INV_GAMMA 0.454545
void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    float roll = 0.0;
    float nearP = 1.0;
    vec3 ta = vec3(0.0);
    vec3 ro = ta + vec3(0.0, 5.0, -10.0);
    vec2 uv = (2.0 * (fragPos) - iResolution.xy) / iResolution.y;
    mat3 cam2World = SetCamera(ro, ta, roll);
    vec3 rd = cam2World * normalize(vec3(uv, nearP));

    vec3 col;// = Render(ro, rd);
    col += hash(dot(uv, vec2(12.9898, 78.233)));

    col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}