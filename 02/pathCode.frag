#iChannel0 "self"

#define GI_BOUNCES 3
#define MAX_DIST 100.0
#define MAX_STEPS 400
#define MIN_DIST 0.0001 

float 
hash(float seed)
{
    return fract(sin(seed)*43758.5453 );
}

mat3
SetCamera(vec3 eye, vec3 tar, float roll)
{
    vec3 f, r, u;
    f = normalize(tar - eye);
    vec3 upRoll = normalize(vec3(sin(roll), cos(roll), 0.0));
    r = normalize(cross(upRoll, f));
    u = normalize(cross(f, r));

    return mat3(r, u, f);
}

float
Map(vec3 p)
{
    float d = 1e10;
    float d1 = length(p - vec3(0.1, 0.1, 0.0)) - 0.25;
    d = min(d, d1);

    float d2 = p.y  + 0.1;
    d = min(d, d2);

    return d;
}

float
RayMarch(vec3 ro, vec3 rd)
{
    float res = -1.0; 
    float t = 0.001;

    for(int i =0 ; i < MAX_STEPS; ++i)
    {
        float h = Map(ro + t *rd);
        if(h < MIN_DIST || t > MAX_DIST ) break;
        t += h;
    }
    
    if (t < MAX_DIST) res = t;

    return res;
}

vec3
CalcNormal(vec3 p)
{
    vec2 e = vec2(0.0001, 0.0);
    return normalize(vec3(Map(p + e.xyy) - Map(p - e.xyy),
                          Map(p + e.yxy) - Map(p - e.yxy),
                          Map(p + e.yyx) - Map(p - e.yyx)
    ));
}

//vec3 skyCol =  4.0*vec3(0.2,0.35,0.5);
vec3 skyCol =  vec3(0.0,0.35,0.5);

vec3
Render(vec3 ro, vec3 rd, float randfloat)
{
    vec3 tot = vec3(0.0);

    float primaryRay = 0.0;

    //GI bounces
    for(int bounce = 0; bounce < GI_BOUNCES; ++bounce)
    {
        float t = RayMarch(ro, rd);

        //Early out if you hit the sky
        if(t < 0.0)
        {
            //But not before adding sky color only once 
            if(bounce == 0)
                return skyCol;
            break;
        }

        //Record how much the primary travelled
        if(bounce == 0) 
            primaryRay = t;
        
        vec3 P = ro + t * rd;
        vec3 N = CalcNormal(P);

        tot += N;
    }

    return tot;
}

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    //RNG 
    float seed = hash(dot(fragPos, vec2(12.9898, 78.233)) + 1131.1*float(iFrame));

    //Offset gives us jitter supersample antialiasing thru random jittering
    vec2 offset = - 0.5  + vec2(hash(seed + 13.271), hash( seed + 63.216));
    vec2 uv = ((fragPos + offset) - 0.5*iResolution.xy) / iResolution.y;

    //Ray setup
    float roll = 0.0;
    float nearP = 1.0;
    vec3 ta = vec3(0.0, 0.0, 0.0);
    vec3 ro = ta +  vec3(0.0, 0.1, -1.0);
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearP));

    //Color setup
    vec2 screen = fragPos / iResolution.xy;
    vec3 col = texture(iChannel0, screen).xyz;

    //First frame init to zero 
    if (iFrame == 0) col = vec3(0.0);

    //Path trace single ray add result to previous buffer
    col += Render(ro, rd, seed);

    fragColor = vec4(col,  1.0);
}