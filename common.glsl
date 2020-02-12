#define INV_GAMMA  0.454545
#define M_PI acos(-1.0)
#define M_TAU M_PI*2.0

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
float
hash(float seed)
{
    uvec2 p = floatBitsToUint(vec2(seed+=.1,seed+=.1));
    p = 1103515245U*((p >> 1U)^(p.yx));
    uint h32 = 1103515245U*((p.x)^(p.y>>3U));
    uint n = h32^(h32 >> 16);
    return float(n)/float(0xffffffffU);
}

//------------------------------------------------------------------------------------
//----------------------------------Path Trace functions------------------------------
vec3
CosineWeightedRay(vec3 N, float seed)
{
    float u = hash(seed + 70.93);
    float v = hash(seed + 21.43);

    float a = M_TAU*v;
    u = 2.0*u - 1.0;

    return(normalize(N + vec3(sqrt(1.0 - u*u)*vec2(cos(a), sin(a)), u)));
}