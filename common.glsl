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


