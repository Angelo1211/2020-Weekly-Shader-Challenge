#include "./common.glsl"

#define INV_GAMMA 0.454545
#define MAX_STEPS 200
#define MAX_DIST 20.0
#define MIN_DIST 0.001
#define AA 2

float
hash(vec2 n){
    return fract(sin(dot(n,vec2(12.9898, 4.1414)))*43758.5453);
}

float _doom = 0.0;

float
SmoothNoise(vec2 uv){
    vec2 lv = fract(uv);
    vec2 id = floor(uv);

    lv = lv*lv*(3.0 - 2.0*lv);
    float bl = hash(id);
    float br = hash(id + vec2(1.0, 0.0));
    float b = mix(bl, br, lv.x);

    float tl = hash(id + vec2(0.0, 1.0));
    float tr = hash(id + vec2(1.0, 1.0));
    float t = mix(tl, tr, lv.x);

    return mix(b, t, lv.y);
}

float
ValueNoise(vec2 uv, int octaves){
    float amplitude = 1.0;
    float frequency = 1.0;
    float noise = 0.0;
    float totalAmp = 0.0;

    for(int i = 0; i < octaves; ++i){
        noise += SmoothNoise(uv * frequency) * amplitude;
        totalAmp += amplitude;
        amplitude /= 2.0;
        frequency *= 2.0;
    }

    return noise / totalAmp ;
}

float
sdTerrain(vec3 pos){
    return pos.y - ValueNoise(pos.xz, 8);
}

vec2
Map(vec3 pos){
    vec2 res = vec2(1e10, -1.0);

    res = uop(res, vec2(sdTerrain(pos), 1.0));
    res = uop(res, vec2(sdSphere(pos - vec3(0.0, 5.0, 0.0), 3.5 * (1.0 - _doom) + 0.7), 0.0));

    return res;
}

vec2
RayMarch(vec3 ro, vec3 rd){
    vec2 res = vec2(-1.0, -1.0);
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i){
        vec2 hit = Map(ro + t*rd);

        if(hit.x < MIN_DIST){
            res = vec2(t, hit.y);
            break;
        }

        t += hit.x;
    }


    return res;
}

vec3 
CalcNormals(vec3 p){
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(Map(p + e.xyy).x - Map(p - e.xyy).x,
                          Map(p + e.yxy).x - Map(p - e.yxy).x,
                          Map(p + e.yyx).x - Map(p - e.yyx).x
    ));
}

float
CalcSoftShadows(vec3 ro, vec3 rd){
    float k = 4.0;
    float n = 1.0;
    for(float t = 0.02; t < MAX_DIST;){
        float h = Map(ro + t*rd).x;
        
        if(h < MIN_DIST){
            return 0.0;
        }
        n = min(n, h*k/t);
        t += h;
    }

    return n;
}

vec3
Render(vec3 ro, vec3 rd, vec2 uv){
    vec2 res = RayMarch(ro, rd);
    float t = res.x;
    float id = res.y;

    //Sky
    vec3 col = vec3(0.0);
    col += vec3(1.0) * pow(hash(uv * vec2(13.0, 2.2)), 703.58);
    col *= 100.0* (_doom*_doom*_doom);

    if(id >= 0.0){
        //Geometry
        vec3 P = ro + t*rd;
        vec3 N = CalcNormals(P);

        //Material
        float fresnel = 0.0;
        vec3 planetCol = vec3(0.1, 0.3, 0.7);
        if (id == 0.0){
            col = planetCol;
            fresnel = 0.04 + (1.0 - 0.04)*pow(1.0 - dot(N,-rd), 5.0);
        }
        else{
            col = vec3(1.0)*N.y;
            fresnel = 0.0;
        }

        //Lighting
        vec3 L = normalize(vec3(0.0, _doom, 1.2));
        vec3 lin = vec3(0.0);
        float dif = saturate(dot(N, L));

        //Shadowing
        dif *= CalcSoftShadows(P, L);

        //Shading
        lin += 1.0 * dif * vec3(1.1, 0.9, 0.78);
        lin += (0.8 - _doom*_doom)* 20.0 * fresnel * vec3(1.0)* 0.01;
        lin += (0.8 - _doom)* 0.01 * planetCol;
        col *= lin *(pow(_doom, 0.7));
    }

    return saturate(col);
}

void
mainImage(out vec4 fragColor, in vec2 fragPos){
    float time  = mod(iTime, 45.45);
    _doom = (sin(time/ 16.0 - 1.4 *M_PI) + 1.0)/ 2.0 ;
    vec3 tot = vec3(0.0);
    //Camera setup
    float near = 1.0;
    float roll = 0.0;
    vec3 ro = vec3(0.0, 2.0, -20.0);
    vec3 tar = vec3(0.0);
    mat3 cam = SetCamera(ro, tar, roll);
#if AA > 1
    for(int i = 0; i < AA; ++i)
    for(int j = 0; j < AA; ++j){
        vec2 offset = vec2(float(i), float(j))/ float(AA) - 0.5;
        vec2 uv = ((fragPos+offset) - 0.5*iResolution.xy)/ iResolution.y;
#else
        vec2 uv = ((fragPos) - 0.5*iResolution.xy)/ iResolution.y;
#endif

        vec3 rd = cam * normalize(vec3(uv, near));

        vec3 col = Render(ro, rd, uv);

        col = pow(col, vec3(INV_GAMMA));

        tot += col;
    #if AA > 1
    }
    tot /= float(AA * AA);
    #endif
    
    fragColor = vec4(tot, 1.0);
}