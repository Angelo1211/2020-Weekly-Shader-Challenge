//Practice sesion 0: 04/21/20

mat3
SetCamera(vec3 ro, vec3 ta, float roll)
{
    vec3 i, j, k, jTemp;
    k = normalize(ta - ro);
    jTemp = normalize(vec3(sin(roll), cos(roll), 0.0));
    i = normalize(cross(jTemp, k));
    j = cross(k, i);
    return mat3(i, j , k);
}

float
hash(vec2 uv)
{
    return fract(sin(dot(uv,vec2(12.9898, 4.1414)))*43758.5453);
}


float
smoothNoise(vec2 uv)
{
    vec2 id = floor(uv);
    vec2 fv = fract(uv);
    fv = fv*fv *(3.0 - 2.0 *fv);

    //bl: bottom left
    float bl = hash(id);
    float br = hash(id + vec2(1.0, 0.0));
    float b = mix(bl, br, fv.x);

    float tl = hash(id + vec2(0.0, 1.0));
    float tr = hash(id + vec2(1.0, 1.0));
    float t = mix(tl, tr, fv.x);

    return mix(b, t, fv.y);
}

float
ValueNoise(vec2 uv, int octaves){
    float amplitude = 1.0;
    float frequency = 1.0;
    float noise = 0.0;
    float totalAmp = 0.0;

    for(int i = 0; i < octaves; ++i){
        noise += smoothNoise(uv * frequency) * amplitude;
        totalAmp += amplitude;
        amplitude /= 2.0;
        frequency *= 2.0;
    }

    return noise / totalAmp ;
}

float
terrain(vec3 p)
{
    return p.y - valueNoise(p.xz, 8.0);
}

#define MAX_STEPS 200
#define MIN_DIST 0.001
#define MAX_DIST 200.0
#define SLOW_DOWN 1.0
float
intersectTerrain(vec3 ro, vec3 rd)
{
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        float h = terrain(ro + t*rd);

        if(abs(h) < MIN_DIST*t) break;

        t += SLOW_DOWN * h;
    }

    return t;
}

vec3
Render(vec3 ro, vec3 rd)
{
    //Terrain Raymarch
    float t = intersectTerrain(ro, rd);

    t /= 100.0;

    return vec3(t);
}

#define INV_GAMMA 0.454545
void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    float nearp = 1.0;
    float roll = 0.0;

    vec3 ta = vec3(0.0);
    vec3 ro = ta + vec3(0.0, 3.0, -10.0); 
    vec2 uv = (2.0 * (fragPos) - iResolution.xy) / iResolution.y;
    mat3 cam2World = SetCamera(ro, ta, roll);
    vec3 rd = cam2World * normalize(vec3(uv, nearp));

    vec3 col = Render(ro, rd);

    col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}