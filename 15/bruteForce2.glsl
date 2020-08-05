#include "./hashes.glsl"

// const data
const float R_atmo        = 6420e3;
const float R_earth       = 6360e3;
const float R_atmo_height = R_atmo - R_earth;
const float M_PI          = 3.14159265352;

//TODO Get a better approx
#if 1
const vec3 S_Luminance = vec3(1e5);
#else
const vec3 S_Luminance = 1e1 * vec3(0.98, 0.83, 0.25);
#endif

vec3 gamma = vec3(6.5e-7, 5.1e-7, 4.75e-7);

#if 0
vec3 Beta_R = vec3(6.55e-6, 1.73e-5, 2.30e-5); // Bodare paper
#else
vec3 Beta_R = vec3(5.8e-6, 1.35e-5, 3.31e-5); // Frostbite sky 
//vec3 Beta_R = vec3(4.9232e-6, 1.15e-5, 2.80e-5); // Test
#endif


const vec3 Beta_M = vec3(4.5e-6);

const float H_Mie      = 1200.0;
const float H_Rayleigh = 8000.0;

const int NumSamples   = 32;

// uniforms
float time = 0.0;
vec3 sunDir = vec3(0.0);

mat3 
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 temp = normalize(vec3(sin(roll), cos(roll), 0.0));

    vec3 k = normalize(target - eye);
    vec3 i = normalize(cross(temp, k));
    vec3 j = cross(k, i);

    return mat3(i, j, k);
}

vec2 
RayIntersectSphere(vec3 ro, vec3 rd, vec3 sOrigin, float r)
{
    ro -= sOrigin;
    float A = dot(rd, rd);
    float B = 2.0 * dot(ro, rd);
    float C = dot(ro, ro) - r * r;
    float discriminant = B * B - 4.0 * A * C;

    // Ray never hits sphere
    if (discriminant < 0.0)
         return vec2(-1.0);

    float t0 = (-B - sqrt(discriminant)) / 2.0 * A;
    float t1 = (-B + sqrt(discriminant)) / 2.0 * A;

    return vec2(t0, t1);
}

float 
rayleighPhaseFunction(float cosTheta)
{
    return     3.0 * (1.0 + cosTheta * cosTheta)
    / //------------------------------------------------
                            4.0;
}

float 
henyeyGreensteinPhaseFunc(float cosTheta)
{
    const float g = 0.76;

    return            3.0*(1.- g*g) * (1.0 + cosTheta * cosTheta)  
    / //----------------------------------------------------------------------
            (2.0*(2.0 + g*g) * pow(1. + g*g - 2.*g*(cosTheta * cosTheta), 1.5));
}

float
GetHeight(vec3 p)
{
    #if 1
    return clamp(length(p) - R_earth, 0.0, R_atmo_height);
    #else 
    return (length(p) - R_earth);
    #endif
}

vec2
GetDensity(float h)
{
    float rayleighDensity = exp(-h / H_Rayleigh);
    float mieDensity      = exp(-h / H_Mie);

    return vec2(rayleighDensity, mieDensity);
}

vec3
Transmittance(vec3 P_a, vec3 P_b)
{
    float rayLength = length(P_b - P_a);
    float stepSize_t =  rayLength / float(NumSamples);
    //NOTE: Direction does not matter for integration purposes
    vec3 rd = (P_b - P_a) / rayLength;

    //                     vec2(Rayleigh, Mie)
    vec2 totalDensity    = vec2(0.0);
    vec2 currentDensity  = vec2(0.0);

    vec2 previousDensity = GetDensity(GetHeight(P_a));
    for(int step_t = 1; step_t < NumSamples; ++step_t )
    {
        vec3 pos_t = P_a + rd * (stepSize_t * float(step_t));

        //Make sure you don't intersect with the earth
        float h = GetHeight(pos_t);
        currentDensity = GetDensity(h);

        totalDensity += stepSize_t * (currentDensity + previousDensity) / 2.0;

        previousDensity = currentDensity;
    }

    return exp(-(totalDensity.x * Beta_R + totalDensity.y * Beta_M/0.9) );
}

vec3
SingleScattering(vec3 ro, vec3 rd)
{
    /*
        Rayleigh:
        Intensity_R = LightIntensity * Phase_R * (Coefficient_R / 4 * pi) *
                      Integral_R( from(P_a, P_b) of ( density_R(height(p)) * T(P_C, P) * T(P, P_A) ) WRT(P))
        Mie:
        Intensity_M = LightIntensity * Phase_M * (Coefficient_M / 4 * pi) *
                      Integral_M( from(P_a, P_b) of ( density_M(height(p)) * T(P_C, P) * T(P, P_A) ) WRT(P))
    */
    vec3 Integral_R = vec3(0.0);
    vec3 current_R  = vec3(0.0);
    vec3 Integral_M = vec3(0.0);
    vec3 current_M  = vec3(0.0);

    // Setting up view ray values
    vec2 atmoHit_V   = RayIntersectSphere(ro, rd, vec3(0.0), R_atmo);
    vec2 groundHit_V = RayIntersectSphere(ro, rd, vec3(0.0), R_earth);
    vec2 atmoHit_S   = RayIntersectSphere(ro, sunDir, vec3(0.0), R_atmo);

    vec2 density_Start = GetDensity(GetHeight(ro));
    vec3 transmittance = exp(-(density_Start.x * Beta_R + density_Start.y * Beta_M )); 
    transmittance *= Transmittance(ro, ro + sunDir * atmoHit_S.y);

    vec3 previous_R = density_Start.x * transmittance;
    vec3 previous_M = density_Start.y * transmittance;

    //Correcting for ground hit
    float rayLength = atmoHit_V.y;
    if(groundHit_V.x > 0.0) rayLength = groundHit_V.x;

#if 1 
    float stepSize_V = rayLength / float(NumSamples);
#else
    vec3 Pb = ro + rd*rayLength;
    float stepSize_V = length(Pb - ro) / float(NumSamples);
#endif

    // Ray marching -> view ray
    for(int step_v = 1; step_v < NumSamples; ++step_v )
    {
        vec3 pos_V = ro + rd * (stepSize_V * float(step_v));
        float h = GetHeight(pos_V);
        //if(h == 0.0) return vec3(1.0, 0.0, 0.0);
        vec2 den_V = GetDensity(h);

        // current pos -> sun 
        vec3 transmittance = Transmittance(ro, pos_V);
        transmittance *= Transmittance(pos_V, pos_V + sunDir*atmoHit_S.y);

        current_R = den_V.x * transmittance;
        current_M = den_V.y * transmittance;

        Integral_R += (stepSize_V / 2.0) * (current_R + previous_R);
        Integral_M += (stepSize_V / 2.0) * (current_M + previous_M);

        previous_R = current_R;
        previous_M = current_M;
    }
    
    /*
        Total Intensity:
        Sum of Intensities = Intensity_R + Intensity_M
        Calculating the sum of intensities directly
    */
    float cosTheta_v = dot(rd, sunDir);
    float Phase_R = rayleighPhaseFunction(cosTheta_v);
    float Phase_M = henyeyGreensteinPhaseFunc(cosTheta_v);

    return  ( (Phase_R * ( Beta_R / (4.0 * M_PI)) * Integral_R ) +
                           (Phase_M * ( Beta_M / (4.0 * M_PI)) * Integral_M ) );
}

vec3
MultiScattering(vec3 ro, vec3 rd, int bounces)
{


    return ro;
}

#define INV_GAMMA 0.454545
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 col = vec3(0.0);

    // Init common vars
    time = iTime / 10.0;

#if 0
    float n = 1.0003;
    float Ne = 2.545e25;
    Beta_R =
            8.0 * M_PI * M_PI * M_PI * pow(n*n - 1.0, 2.0)
    / //--------------------------------------------------
                     (3.0 * Ne * pow(gamma, vec3(4.0))); 
#endif

    // Fixed/moving sun
#if 0
    sunDir = normalize(vec3(1.0, -0.12, 0.0));
#else
    sunDir = normalize(vec3(sin(time), abs(cos(time)) - 0.5, 0.0));
#endif

    // We want -1 to 1
    vec2 uv = 2.0 * ((fragCoord)-0.5 * iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0.0, 1.0 + R_earth, 0.0);

#if 1
    // Fisheye cam pointing up at the sky
    const float hemiRadius = 1.0;
    float length2 = dot(uv, uv);
    if (length2 > hemiRadius)
        return;
    float phi = atan(uv.y, uv.x);

#if 1
    float theta = acos(sqrt(hemiRadius - length2));
#else
    float theta = acos((hemiRadius - length2));
#endif
    vec3 rd_WS = vec3(sin(theta) * cos(phi), cos(theta), sin(theta) * -sin(phi));
    rd_WS = normalize(rd_WS);
#else
    // Pinhole cam pointing east
    vec3 ta = ro + vec3(1.0, 0.0, 0.0);
    const float nearPlane = 1.0;
    mat3 cam = SetCamera(ro, ta, 0.0);
    vec3 rd_WS = cam * normalize(vec3(uv, nearPlane));
#endif

    float cutoff = -2.0;
    #if 0
    cutoff = sin(time * 1.0);
    #endif

    if(uv.x > cutoff)
    {
        //Single Scatter
        col = SingleScattering(ro, rd_WS);
    }
    else
    {
        //Multi Scatter
        const int bounces = 5;
        col = MultiScattering(ro, rd_WS, bounces);
    }

    //Vertical line
    col = (abs(uv.x - cutoff) < 0.005) ? vec3(1.0, 0.0, 1.0) : col;

#if 1 
    float exposure = 10.00;
    vec3 white_point = vec3(1.08241, 0.96756, 0.95003);

    col = vec3(1.0) - exp(-col/white_point * exposure);
    col = pow(col, vec3(INV_GAMMA));
#endif
    fragColor = vec4(col, 1.0); 
}