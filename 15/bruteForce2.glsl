#include "./hashes.glsl"

// const data
const float R_earth = 6360e3;
const float R_atmo = 6420e3;
const float M_PI = 3.14159265352;

const float S_Luminance = 2e10;
const vec3 Beta_R = vec3(6.55e-6f, 1.73e-5f, 2.30e-5f);
const vec3 Beta_M = vec3(2.0e-6);

const float NumSamples = 16.0;
const float H_Air = 7994.0;
const float H_Aerosols = 1200.0;

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

vec3 
RayIntersectSphere(vec3 ro, vec3 rd, vec3 sOrigin, float r, inout float t0, inout float t1)
{
    ro -= sOrigin;
    float A = dot(rd, rd);
    float B = 2.0 * dot(ro, rd);
    float C = dot(ro, ro) - r * r;
    float discriminant = B * B - 4.0 * A * C;

    // Ray never hits sphere
    if (discriminant < 0.0)
         return vec3(-1.0);

    t0 = (-B - sqrt(discriminant)) / 2.0 * A;
    t1 = (-B + sqrt(discriminant)) / 2.0 * A;

    return ro + t1*rd;
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
            ((4. * M_PI) * pow(1. + g*g - 2.*g*(cosTheta* cosTheta), 1.5));
}

vec2
GetDensity(vec3 p)
{
    float h = length(p) - R_earth;

    // returns vec2(Density Rayleigh, Density Mie)
    return exp(- h / vec2(H_Air, H_Aerosols));
}

vec3
Transmittance(vec3 P_a, vec3 P_b)
{
    float stepSize_t = length(P_b - P_a) / NumSamples;

    // vec2(Rayleigh, Mie)
    vec2 totalDensity = vec2(0.0);
    vec2 previousDensity = vec2(0.0);
    vec2 currentDensity = vec2(0.0);

    vec3 rd = normalize(P_b - P_a);
    for(float step_t = 0.0; step_t < NumSamples; ++step_t )
    {
        vec3 pos_t = P_a + rd * (stepSize_t * step_t);
        currentDensity = GetDensity(pos_t);

        totalDensity += (currentDensity + previousDensity)/ (2.0 * stepSize_t);

        previousDensity = currentDensity;
    }

    return exp(-(totalDensity.x * Beta_R + totalDensity.y * Beta_M) );
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
    vec3 current_R = vec3(0.0);
    vec3 previous_R = vec3(0.0);

    vec3 Integral_M = vec3(0.0);
    vec3 current_M = vec3(0.0);
    vec3 previous_M = vec3(0.0);

    // Setting up view ray values
    float t0_V = 0.0;
    float t1_V = 0.0;

    float t0_S = 0.0;
    float t1_S = 0.0;

    // Early rejection if your ray is outside of the earth
    RayIntersectSphere(ro, rd, vec3(0.0), R_atmo, t0_V, t1_V);

    // Ray marching -> view ray
    vec3 transmittance =  vec3(0.0);
    float stepSize_V = t1_V / NumSamples;

    for(float step_v = 0.0; step_v < NumSamples; ++step_v )
    {
        vec3 pos_V = ro + rd * (stepSize_V * step_v);
        vec2 den_V = GetDensity(pos_V);

        // view ray -> sun 
        vec3 hit_S = RayIntersectSphere(pos_V, sunDir, vec3(0.0), R_atmo, t0_S, t1_S);

        transmittance = Transmittance(ro, pos_V) * Transmittance(pos_V, hit_S);

        current_R = den_V.x * transmittance;
        current_M = den_V.y * transmittance;

        Integral_R = (current_R + previous_R) / (2.0 * stepSize_V);
        Integral_M = (current_M + previous_M) / (2.0 * stepSize_V);

        previous_M = current_M;
        previous_R = current_R;
    }
    
    /*
        Total Intensity:
        Sum of Intensities = Intensity_R + Intensity_M
        Calculating the sum of intensities directly
    */
    float cosTheta_v = dot(rd, sunDir);
    float Phase_R = rayleighPhaseFunction(cosTheta_v);
    float Phase_M = henyeyGreensteinPhaseFunc(cosTheta_v);

#if 0
    return S_Luminance * ( (Phase_R * ( Beta_R / 4.0 * M_PI) * Integral_R ) );
#else
    return S_Luminance * ( (Phase_R * ( Beta_R / 4.0 * M_PI) * Integral_R ) +
                           (Phase_M * ( Beta_M / 4.0 * M_PI) * Integral_M ) );
#endif
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
    //Random val per pixel per frame
    float seed = hash11(dot(vec2(12.9898, 78.233),fragCoord) + 1113.1*float(iFrame));

    // Init common vars
    time = iTime / 1.0;

    // Fixed/moving sun
#if 0
    sunDir = normalize(vec3(1.0, -0.03, 0.0));
#else
    sunDir = normalize(vec3(sin(time), abs(cos(time)) - 0.5, 0.0));
#endif

    // We want -1 to 1
    vec2 uv = 2.0 * ((fragCoord)-0.5 * iResolution.xy) / iResolution.y;
    vec3 ro = vec3(0.0, 1.0 + R_earth, 0.0);

#if 0
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

    vec3 col = vec3(0.0);
    float cutoff = -2.4;
#if 0
    cutoff = sin(time* 20.0);

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
#else
    col = SingleScattering(ro, rd_WS);
#endif

    //Vertical line
    col = (abs(uv.x - cutoff) < 0.005) ? vec3(0.0, 1.0, 0.0) : col;

    col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0); 
}