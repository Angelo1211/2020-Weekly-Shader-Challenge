//Practice 0: 28/04/20 (18m)

#include "./hashes.glsl"

float
smoothNoise(vec2 uv)
{
    vec2 id = floor(uv);
    vec2 fr = fract(uv);

    fr = fr * fr * (3.0 - 2.0*fr);

    float bl = hash12(id + vec2(0.0, 0.0 ));
    float br = hash12(id + vec2(1.0, 0.0 ));
    float b = mix(bl, br, fr.x);

    float tl = hash12(id + vec2(0.0, 1.0 ));
    float tr = hash12(id + vec2(1.0, 1.0 ));
    float t = mix(tl, tr, fr.x);

    return mix(b, t, fr.y);
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
        totalAmplitude += amplitude;
        noise += smoothNoise(uv * frequency) * amplitude;
        amplitude /= 2.0;
        frequency *= 2.0;
    }
    noise /= totalAmplitude;

    return noise;
}

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 i, j ,k, temp;

    k = normalize(target - eye);
    temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    i = normalize(cross(temp, k));
    j = cross(k, i);

    return mat3(i, j, k);
}

#define HI_LOD 8
#define LO_LOD 4
float
terrain(vec3 p, int lod)
{
    return p.y - valueNoise(p.xz, lod);
}

#define MAX_DIST 200.0
#define MAX_STEPS 70
#define MIN_DIST 0.001
float
intersectTerrain(vec3 ro, vec3 rd)
{
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        float h = terrain(ro + t*rd, HI_LOD);

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

    return saturate(col);
}

#define INV_GAMMA 0.45454545
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Camera setup
    float roll = 0.0;
    float nearp = 1.0;
    vec3 ta = vec3(0.0 + iTime, 0.0, 0.0 + iTime * 0.2);
    vec3 ro = ta + vec3(0.0, 2.0, -10.0);
    vec2 uv = ((fragCoord) - 0.5*iResolution.xy)/ iResolution.y;

    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearp));
    vec3 col = Render(ro, rd);
    //col = vec3(hash12(uv));
    //col = vec3(smoothNoise(uv));
    //col = vec3(valueNoise(uv* 2.0 + iTime, 8));

    //col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}

/*

    def lerp(t, a, b):
        return (1-t)*a + b*t;

    n = lerp(w, lerp(v, lerp(u, a, b) ,lerp(u, c, d)),
    lerp(v, lerp(u, e, f), lerp(u, g, h)));

    simplify 1:
    n = lerp(w, lerp(v, (1-u)*a + b*u, (1 -u)*c + c*d)),
       lerp(v, (1-u)*e + u*f), (1-u)*g + u*h)));


this is the func you really need to understand
float terrainH( in vec2 x )
{
	vec2  p = x*0.003/SC;
    float a = 0.0;
    float b = 1.0;
	vec2  d = vec2(0.0);
    for( int i=0; i<16; i++ )
    {
        vec3 n = noised(p);
        d += n.yz;
        a += b*n.x/(1.0+dot(d,d));
		b *= 0.5;
        p = m2*p*2.0;
    }

	return SC*120.0*a;
}



*/