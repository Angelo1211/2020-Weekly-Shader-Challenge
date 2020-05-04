//Practice 0: 28/04/20 (18m)
//Practice 1: 29/04/20 (18m)
//Practice 2: 30/04/20 (23m)
//Practice 3: 02/05/20
//Practice 4: 03/05/20
//Practice 5: 04/05/20

#iChannel0 "./textures/mediumNoise.png"
#include "./hashes.glsl"
#define USE_NOISE_TEXTURE 1

vec3
dNoise2D(vec2 uv)
{
    ivec2 id = ivec2(floor(uv));
    vec2 fr = fract(uv);

    vec2 interp  = fr*fr*(3.0 - 2.0*fr);
    vec2 dInterp = 6.0*fr*(1.0 - fr);

    float bl = 0.0;
    float br = 0.0;
    float b  = 0.0;
    float tl = 0.0;
    float tr = 0.0;
    float t  = 0.0;
#if USE_NOISE_TEXTURE
    bl = texelFetch(iChannel0, id + ivec2(0, 0)&255, 0).x;
    br = texelFetch(iChannel0, id + ivec2(1, 0)&255, 0).x;

    tl = texelFetch(iChannel0, id + ivec2(0, 1)&255, 0).x;
    tr = texelFetch(iChannel0, id + ivec2(1, 1)&255, 0).x;
#else
    bl = hash12(vec2(id) + vec2(0,0));
    br = hash12(vec2(id) + vec2(1,0));

    tl = hash12(vec2(id) + vec2(0,1));
    tr = hash12(vec2(id) + vec2(1,1));
#endif
    b  = mix(bl, br, interp.x);
    t  = mix(tl, tr, interp.x);

    float noise = mix(b,t, interp.y);
    vec2 derivatives = dInterp*(vec2(br - bl, tl - bl) + (bl - br - tl + tr)*interp.yx );

    return vec3(noise, derivatives);
}

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 temp = vec3(0.0);
    vec3 i = vec3(0.0);
    vec3 j = vec3(0.0);
    vec3 k = vec3(0.0);

    temp = normalize(vec3(sin(roll), cos(roll), 0.0));

    k = normalize(target - eye);
    i = normalize(cross(temp, k));
    j = cross(k, i);

    return mat3(i, j, k);
}

//const mat2 m2 = mat2(0.8,-0.6, 0.6,0.8);
const mat2 m2 = mat2(1.0);

float terrainH( in vec2 uv, int octaves)
{
    float TERRAIN_FREQ = 1.0;
    float TERRAIN_HEIGHT = 1.0;
    vec2  sample_point = uv * TERRAIN_FREQ;
    float a = 0.;
    float b = 1.;
	vec2  derivatives = vec2(0.);
    
    for (int i = 0; i < octaves; ++i)
    {
        vec3 noise = dNoise2D(sample_point); //x is noise, yz are noise derivatives

        derivatives += noise.yz;

        a +=            (b * noise.x)
            / //--------------------------------------
              (1. + dot(derivatives, derivatives));

		b *= .5;

        sample_point = m2 * sample_point * 2.;
    }
    
    a = abs(a) * 2. - 1.;
    
    return smoothstep(-.95, .5, a) * a * TERRAIN_HEIGHT;
}

float terrainM( in vec2 x, int octaves )
{
    float SC = 1.0;
    float frequency =  0.003;
	vec2  p = x/SC;
    float noise = 0.0;
	vec2  totalDerivatives = vec2(0.0);
    float b = 1.0;
    for( int i=0; i<octaves; i++ )
    {
        vec3 n = dNoise2D(p);
        noise += b*n.x/(1.0+dot(totalDerivatives, totalDerivatives));
        totalDerivatives += n.yz; 
		b *= 0.5;
        p = m2*p*2.0;
    }
    float magicNum = 120.0;
	return SC*magicNum*noise;
}

float
terrain(vec3 p)
{
    return p.y - terrainM(p.xz, 8);
}

#define MAX_DIST 200.0
#define MAX_STEPS 200
#define MIN_DIST 0.001
float
intersectTerrain(vec3 ro, vec3 rd)
{
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS; ++i)
    {
        float h = terrain(ro + t*rd);

        if(abs(h) < t*MIN_DIST) break;

        t +=h;
    }

    return t;
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col = vec3(0.0);

    float t = intersectTerrain(ro, rd);

    col += t / 10.0;

    return saturate(col);
}

#define INV_GAMMA 0.454545
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Camera
    float nearp = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0, 0.0, 0.0);
    vec3 ro = ta + vec3(0.0, 490.0, -10.0);
    vec2 uv = ((fragCoord) - 0.5*iResolution.xy)/ iResolution.y;
    mat3 cam = SetCamera(ro, ta, roll);

    vec3 rd = cam*normalize(vec3(uv, nearp));

    vec3 col = Render(ro, rd);
    //Noise tests
    //col = vec3(texelFetch(iChannel0, ivec2(fragCoord)&255, 0).x);
    //col = vec3(dNoise2D(uv* 20.0).x); //Just the noise
    //col = vec3(dNoise2D(uv*20.0).xyz); //Noise and derivatives

    col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}