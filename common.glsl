#include "./hashes.glsl"

#define INV_GAMMA  0.454545
#define M_PI acos(-1.0)
#define M_TAU M_PI*2.0

//Comment this out if running this file on shadertoy
//#define SHADERTOY 

//------------------------------------------------------------------------------------
//----------------------------------SDF Shaping functions-----------------------------
float
sdSphere(vec3 p, float r)
{
    return length(p) - r;
}

float 
sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float
sdGroundPlane(vec3 p)
{
    return p.y;
}

//------------------------------------------------------------------------------------
//----------------------------------SDF Joining functions-----------------------------
#define UOP(dist, ID) res = uop(res, vec2(dist, ID))
vec2
uop(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

//------------------------------------------------------------------------------------
//----------------------------------Rotation functions--------------------------------
vec2 
rotate(vec2 a, float b)
{
    float c = cos(b);
    float s = sin(b);
    return vec2(
        a.x * c - a.y * s,
        a.x * s + a.y * c
    );
}

//------------------------------------------------------------------------------------
//----------------------------------Noise functions-----------------------------------

// Bilinear filter with derivatives Iq style
vec3
bilinearNoiseD(vec2 uv)
{
    vec2 id = floor(uv);
    vec2 fr = fract(uv);

    // Cubic interpolation
    vec2 interp = fr * fr * (3.0 - 2.0*fr);

    // Cubic interp derivative
    vec2 interp_D = 6.0 * fr * (1.0 - fr);

    // Bottom
    float bl = hash12(id + vec2(0.0, 0.0));
    float br = hash12(id + vec2(1.0, 0.0));
    float b  = mix(bl, br, interp.x); 

    // Top
    float tl = hash12(id + vec2(0.0, 1.0));
    float tr = hash12(id + vec2(1.0, 1.0));
    float t  = mix(tl, tr, interp.x); 

    // Filtered noise result
    float noise = mix(b, t, interp.y);

    //checkout pdf week 14 for where this comes from
    vec2 dNoise = interp_D * (vec2(-bl + br, -bl + tl) + (bl - br - tl + tr) * interp.yx  );
    return vec3(noise, dNoise);
}

float
terrainNoise(vec2 uv, const int octaves, const float terrain_height, const float terrain_freq)
{
    const mat2 m2 = mat2(0.8,-0.6,0.6,0.8);

    vec2  pos = uv * terrain_freq; // Position
    float noise = 0.;
    float amplitude = 1.;
    vec2  derivatives = vec2(0.);
    
    for (int i = 0; i < octaves; ++i)
    {
        vec3 filteredNoise = bilinearNoiseD(pos);
        derivatives += filteredNoise.yz;
        /*
            IQ Email:
            1. First intuition - the gradient measures both the direction of biggest change 
            (meaning, the steepest slope) and its magnitude (the inclination). So, that squared
            gives us a measure of inclination. I could have square-rooted it to get proper units,
            but that'd have been slower.

            2. Second intuition - dividing the noise by the amount of inclination was my crude attempt at
            simulation erosion, the motivation being that in areas of high inclination the soil, pebbles and rocks
            roll down, lowering the altitude of the terrain (rain moves them away easily). Areas of low inclination 
            accumulate more rocks and soil (deposited from areas of higher inclination). So,  dividing the noise by the 
            magnitude of its own derivative/inclination I was hoping to get something that resembled an eroded terrain.
        */
        noise += amplitude * filteredNoise.x / (1. + dot(derivatives, derivatives)); // IQ erosion magic using derivatives
        amplitude *= .5; // halving amplitude
        pos = m2 * pos * 2.; // Doubling frequency and rotating noise layer
    }
    
    // [-1..1] ?
    noise = abs(noise) * 2. - 1.;
    
    return smoothstep(-.95, .5, noise) * noise * terrain_height;
}

//------------------------------------------------------------------------------------
//----------------------------------Camera functions------------------------------

/*
    Camera to World transform
*/
mat3
SetCamera(vec3 ro, vec3 ta, float roll)
{
    /*
        Iñigos way:
        vec3 cw = normalize(ta-ro);  
        vec3 cp = vec3(sin(cr), cos(cr),0.0);
        vec3 cu = normalize( cross(cw,cp) );
        vec3 cv =          ( cross(cu,cw) );
        return mat3( cu, cv, cw );
    */
#if 1
    //My version
    vec3 f, temp, r, u;
    f = normalize(ta - ro); 
    temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    r = normalize(cross(temp, f));
    u = (cross(f, r)); //

    return mat3(r, u, f);
#else
    //Inigos version with other names
    vec3 k = normalize(ta-ro);
	vec3 j_temp = vec3(sin(roll), cos(roll),0.0);
	vec3 i = normalize( cross(k,j_temp) ); //This results in -i
	vec3 j =          ( cross(i,k) ); //This results in +j!
    
    /*
        I don't use his because his camera results in a left-handed coordinate sytem.
    */
    return mat3( i, j, k ); // -i, +j, +k?
#endif

}

//------------------------------------------------------------------------------------
//----------------------------------Path Trace functions------------------------------
vec3
CosineWeightedRay(vec3 N, float seed)
{
    float u = hash11(seed + 70.93);
    float v = hash11(seed + 21.43);

    float a = M_TAU*v;
    u = 2.0*u - 1.0;

    return(normalize(N + vec3(sqrt(1.0 - u*u)*vec2(cos(a), sin(a)), u)));
}

//--------------------------------------------------------------------------------------
//----------------------------------Post processing functions----------------------------
#define GAMMA(col) col = pow(col, vec3(INV_GAMMA))


//---------------------------------------------------------------------------------------- 
//----------------------------------Basic functions---------------------------------------
#ifdef SHADERTOY
#define saturate(col) clamp(col, 0.0, 1.0)
#endif

#define UV(screenCoords) vec2 uv = (-iResolution.xy + 2.0*screenCoords) / iResolution.y
#define OUTPUT(col) fragColor = vec4(col, 1.0)


