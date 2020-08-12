
mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 i, j, k, temp;

    k = normalize(target - eye);
    // y i s up
    temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    i = normalize(cross(temp, k));
    j = cross(k, i);

    return mat3(i, j, k);
}

float
sdSphere(vec3 pos, float radius)
{
    return length(pos) - radius;
}

vec2
unionOp(vec2 a, vec2 b)
{
    // Return closest sdf value
    return (a.x < b.x) ? a : b;
}

#define ID_SPHERE 1.0
vec2
Map(vec3 pos)
{
    vec2 res = vec2(1e10, -1.0);

    res = unionOp(res, vec2(sdSphere(pos - vec3(0.1), 0.25), ID_SPHERE));

    return res;
}

#define MAX_DIST 100.0
#define MAX_STEPS 200
#define MIN_DIST 0.001 
vec2
Raymarch(vec3 ro, vec3 rd)
{
    vec2 res = vec2(-1.0, -1.0);
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        vec2 hit = Map(ro + t*rd);

        // Cone-tracing like thing (widening min dist based on current ray length)
        if(abs(hit.x) < MIN_DIST *t)
        {
            res = vec2(t, hit.y);
            break;
        }

        t += hit.x;
    }
    return res;
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col = vec3(0.0);
    // Unpack raymarch results
    vec2 results = Raymarch(ro, rd);
    float t = results.x;
    float id = results.y;

    //Geometry
    vec3 P = ro + t * rd;

    //Lighting
    
    //Shading
    col = P;

    //Post process
    return col;
}

#define AA 1
#define INV_GAMMA 0.454545
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Camera setup
    float roll = 0.0;
    float near_plane = 1.0;
    vec3 target_WS = vec3(0.0, 0.0, 0.0);
    vec3 ray_origin_WS = target_WS + vec3(0.0, 0.0, - 1.0);
    mat3 camera_to_WS = SetCamera(ray_origin_WS, target_WS, roll); 


    vec3 sampleSum = vec3(0.0);

#if AA > 1
    for(int i = 0; i < AA; ++i)
    for(int j = 0; j < AA; ++j)
    {
        vec2 offset = vec2(i, j)/ float(AA) - 0.5;
        vec2 uv = ((fragCoord + offset) - 0.5*iResolution.xy) / iResolution.y;
#else
        vec2 uv = ((fragCoord) - 0.5*iResolution.xy) / iResolution.y;
#endif

        vec3 ray_direction_WS = camera_to_WS * normalize(vec3(uv, near_plane));

        vec3 col = Render(ray_origin_WS, ray_direction_WS);
        col = pow(col, vec3(INV_GAMMA));

        sampleSum += col;
#if AA > 1
    }
    sampleSum /= float(AA * AA);
#endif


    fragColor = vec4(sampleSum, 1.0);
}