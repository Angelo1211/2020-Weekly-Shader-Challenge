//Practice 0: 28/04/20 (18m)
//Practice 1: 29/04/20 (18m)

#include "./hashes.glsl"

#iChannel0 "./textures/MediumNoise.png"

vec3 noised(vec2 uv )
{
    vec2 id = floor(uv);
    vec2 f = fract(uv);
    vec2 u = f*f*(3.0-2.0*f);
    /*
        u = 3.0*f*f - 2.0*f*f*f
          = 6.0*f   - 6.0*f*f
          = 6.0*f*(1-f)
    */

    /*
        u = 3.0*f*f - 2.0*f*f*f
       du = 6.0*f   - 6.0*f*f
          = 6.0*f*(1-f)
    */
    vec2 du = 6.0*f*(1.0-f);

#if 0
    // texel fetch version
    ivec2 p = ivec2(floor(uv));
    float a = texelFetch( iChannel0, (p+ivec2(0,0))&255, 0 ).x;
	float b = texelFetch( iChannel0, (p+ivec2(1,0))&255, 0 ).x;
	float c = texelFetch( iChannel0, (p+ivec2(0,1))&255, 0 ).x;
	float d = texelFetch( iChannel0, (p+ivec2(1,1))&255, 0 ).x;
#else    
    //Noise version
    //Bottom
	float a = hash12(id + vec2(0.0, 0.0));
	float b = hash12(id + vec2(1.0, 0.0));
    float bot = mix(a, b, u.x);

    //Top
	float c = hash12(id + vec2(0.0, 1.0));
	float d = hash12(id + vec2(1.0, 1.0));
    float top = mix(c, d, u.x);

    float smoothNoise = mix(bot, top, u.y);

    /*

        n(x, y) = trilinear interpolation of lattice points as above
        n(x, y) = 

        //∂n/∂x 
    */
    //vec3 derivatives = 


#endif
    
    #if 0
	return vec3(a+(b-a)*u.x+(c-a)*u.y+(a-b-c+d)*u.x*u.y,
				6.0*f*(1.0-f)*(vec2(b-a,c-a)+(a-b-c+d)*u.yx));
    #else
	return vec3(smoothNoise,
				6.0*f*(1.0-f)*(vec2(b-a,c-a)+(a-b-c+d)*u.yx));
    #endif
}

float
smoothNoise(vec2 uv)
{
    //Bilinear interpolation
    vec2 id = floor(uv);
    vec2 fr = fract(uv);

    //interpolation polynomial
    fr = fr*fr*(3.0 - 2.0*fr);

    //bottom
    float bl = hash12(id + vec2(0.0, 0.0));
    float br = hash12(id + vec2(1.0, 0.0));
    float b = mix(bl, br, fr.x);

    //top
    float tl = hash12(id + vec2(0.0, 1.0));
    float tr = hash12(id + vec2(1.0, 1.0));
    float t = mix(tl, tr, fr.x);

    return mix(b, t, fr.y);
}

float
valueNoise(vec2 uv, int octaves)
{
    float noise;
    float totalAmplitude;
    float frequency = 1.0;
    float amplitude = 1.0;

    for(int i = 0; i < octaves; ++i)
    {
        noise += smoothNoise(uv * frequency) * amplitude;
        totalAmplitude += amplitude;
        amplitude /= 2.0;
        frequency *= 2.0;
    }

    return noise/ totalAmplitude;
}

mat3
SetCamera(vec3 eye, vec3 ta, float roll)
{
    vec3 i, j, k, temp;

    k = normalize(ta - eye);
    temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    i = normalize(cross(temp, k));
    j = cross(k, i);

    return mat3(i, j, k);
}

float
terrain(vec3 p, int lod)
{
    return p.y - valueNoise(p.xz, lod);
}

#define MAX_STEPS 200
#define MAX_DIST 200.0
#define MIN_DIST 0.001
float
intersectTerrain(vec3 ro, vec3 rd)
{
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        float h = terrain(ro + rd*t, 8);

        if(abs(h) < t*MIN_DIST) break;

        t += 0.4*h;
    }

    return t;
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col;

    float t = intersectTerrain(ro, rd);

    col += t / 10.0;

    return (col);
}

#define INV_GAMMA 0.454545
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Camera setup
    float nearp = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0 + iTime, 0.0, 0.0 + 0.4*iTime);
    vec3 ro =  ta + vec3(0.0, 2.0, -10.0);
    vec2 uv = ((fragCoord) - 0.5*iResolution.xy)/ iResolution.y;
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearp));
    vec3 col = Render(ro, rd);

    //Noise tests
    col = noised(uv* 20.0);
    //col = vec3(hash12(uv));
    //col = vec3(smoothNoise(uv * 20.0));
    //col = vec3(valueNoise(uv * 2.0 + iTime, 8));

    col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}
