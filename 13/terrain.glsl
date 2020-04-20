#include "./common.glsl"
#iChannel0 "file://./textures/MediumNoise.png"



vec3 valueNoiseDerivative(vec2 x, sampler2D smp)
{
    vec2 f = fract(x);
    vec2 u = f * f * (3. - 2. * f);

#if 1
    // texel fetch version
    ivec2 p = ivec2(floor(x));
    float a = texelFetch(smp, (p + ivec2(0, 0)) & 255, 0).x;
	float b = texelFetch(smp, (p + ivec2(1, 0)) & 255, 0).x;
	float c = texelFetch(smp, (p + ivec2(0, 1)) & 255, 0).x;
	float d = texelFetch(smp, (p + ivec2(1, 1)) & 255, 0).x;
#else    
    // texture version    
    vec2 p = floor(x);
	float a = textureLod(smp, (p + vec2(.5, .5)) / 256., 0.).x;
	float b = textureLod(smp, (p + vec2(1.5, .5)) / 256., 0.).x;
	float c = textureLod(smp, (p + vec2(.5, 1.5)) / 256., 0.).x;
	float d = textureLod(smp, (p + vec2(1.5, 1.5)) / 256., 0.).x;
#endif
    
	return vec3(a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y,
				6. * f * (1. - f) * (vec2(b - a, c - a) + (a - b - c + d) * u.yx));
}

float
terrain(vec2 uv)
{
    #if 0
    float freq = 1.0;
    return sin(iTime + uv.x);
    #else
        float TERRAIN_FREQ = 0.1;
        float TERRAIN_HEIGHT = 0.3;
        const mat2 m2 = mat2(0.8,-0.6,0.6,0.8);

        int octaves = 12;
        vec2  p = uv * TERRAIN_FREQ;
        float a = 0.;
        float b = 1.;
        vec2  d = vec2(0.);
        
        for (int i = 0; i < octaves; ++i)
        {
            vec3 n = valueNoiseDerivative(p, iChannel0);
            d += n.yz;
            a += b * n.x / (1. + dot(d, d));
            b *= .5;
            p = m2 * p * 2.;
        }
        
        a = abs(a) * 2. - 1.;
        
        return smoothstep(-.95, .5, a) * a * TERRAIN_HEIGHT;
    #endif
}

float
intersectTerrain(vec3 ro, vec3 rd, float tMin, float tMax)
{
    float t = tMin;

    const int maxSteps = 100;
    for(int i = 0; (i < maxSteps) && (t < tMax); ++i)
    {
        vec3 pos = ro + t*rd;
        float h = pos.y - terrain(pos.xz);
        if(abs(h) < 0.0015*t)break;

        t += 0.3*h;
    }

    return t;
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col;
    float tMin = 1.0;
    float tMax = 5000.0;

    float t = intersectTerrain(ro, rd, tMin, tMax);

    vec3 p = ro + t*rd;
    col = p;

    //col += t / 300.0;


    return saturate(col);
}

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    UV(fragPos);

    //Camera setup
    float roll = 0.0;
    float nearPlane = 1.0;
    vec3 ta = vec3(0.0);
    vec3 ro = ta + vec3(0.0, 2.0, -5.0);
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearPlane));

    vec3 col = Render(ro, rd);

    GAMMA(col);
    fragColor = vec4(col, 1.0);
}