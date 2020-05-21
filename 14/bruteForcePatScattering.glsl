
// const variables
const float S_Luminance = 20.0;
const float R_earth = 6360e3;
const float R_atmo = 6420e3;
const float H_Air = 7994.0;
const float H_Aerosols = 1200.0;
const vec3 betaRayleigh = vec3(3.8e-6f, 13.5e-6f, 33.1e-6f);
const vec3 betaMie = vec3(21.0e-6);
const int numSamples_V = 16;
const int numSamples_S = 8;
const float M_PI = 3.14159265352;

// uniforms
float time = 0.0;
vec3 sunDir = vec3(0.0);

float 
rayleighPhaseFunction(float mu)
{
    return 3.0 * (1.0 + mu * mu)
    / //----------------------
           (16.0 * M_PI);
}

float 
henyeyGreensteinPhaseFunc(float mu)
{
    const float g = 0.76;

    return                (1. - g * g)
    / //---------------------------------------------
           ((4. * M_PI) * pow(1. + g * g - 2. * g * mu, 1.5));
}

bool 
RayIntersectSphere(vec3 ro, vec3 rd, vec3 sOrigin, float r, inout float t0,
                        inout float t1)
{
    ro -= sOrigin;
    float A = dot(rd, rd);
    float B = 2.0 * dot(ro, rd);
    float C = dot(ro, ro) - r * r;
    float discriminant = B * B - 4.0 * A * C;

    // Ray never hits sphere
    if (discriminant < 0.0)
        return false;

    t0 = (-B - sqrt(discriminant)) / 2.0 * A;
    t1 = (-B + sqrt(discriminant)) / 2.0 * A;

    return true;
}

struct ray
{
    float t1;
    float t0;
    vec3 aersol_density;
    vec3 air_density;
};

vec3
RenderBruteForce(vec3 ro, vec3 rd)
{
    //Results
    vec3 totalRayleigh = vec3(0.0);
    vec3 totalMie = vec3(0.0);

    //Setting up primary ray
    float t0_V = 0.0;
    float t1_V = 0.0;
    vec3 densityAir_V = vec3(0.0);
    vec3 densityAerosols_V = vec3(0.0);

    // Reject rays that are outside of the earth and never interesect it
    // Not really an issue in our demo
    bool hit = RayIntersectSphere(ro, rd, vec3(0.0), R_atmo, t0_V, t1_V);
    if (!hit) return totalRayleigh; // Empty value


    // Calculate the angle between the view ray and the sundirection
    // Possibly premature?
    float mu_v = dot(rd, sunDir);
    float phaseRayleigh_v = rayleighPhaseFunction(mu_v);
    float phaseMie_v = henyeyGreensteinPhaseFunc(mu_v);

    // Subdivide the ray into steps
    float stepSize_V = t1_V / float(numSamples_V);
    float t_V = 0.0;

    //For each step along the view ray
    // O(s^2 * b * d)
#define MAX_STEPS 8
#define MAX_DIRECTIONS 2
#define MAX_BOUNCES 2
    //Order zero scattering p -> v
    for (int step_v = 0; step_v < MAX_STEPS; ++step_v)
    {
        //For each bounce
        for(int order = 2; order < MAX_BOUNCES - 1; ++order)
        {
            //Calculate the next bounce

            //Calculate order one scattering
        }
    }
    return vec3(0.0);
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 totalRayleigh = vec3(0.0);
    vec3 totalMie = vec3(0.0);

    // Setting up view ray values
    float t0_V = 0.0;
    float t1_V = 0.0;
    vec3 densityAir_V = vec3(0.0);
    vec3 densityAerosols_V = vec3(0.0);

    // Early rejection if your ray is outside of the earth
    bool hit = RayIntersectSphere(ro, rd, vec3(0.0), R_atmo, t0_V, t1_V);
    if (!hit) return totalRayleigh; // Empty value

    // Phase functions
    float mu = dot(rd, sunDir);
    float phaseRayleigh = rayleighPhaseFunction(mu);
    float phaseMie = henyeyGreensteinPhaseFunc(mu);

    //For each step along view ray
        //For each scattering order
            //For each direction arround current position
                //For each step along direction from current pos to atmo 

    // Ray marching -> view ray
    float stepSize_V = t1_V / float(numSamples_V);
    float t_V = 0.0;
    for (int i = 0; i < numSamples_V; ++i)
    {
        // Marching along view ray
        {
            vec3 pos_V = ro + rd * (t_V + stepSize_V * 0.5);
            float height_V = length(pos_V) - R_earth;

            // Density at current location
            float airDensityAtPos_V = exp(-height_V / H_Air) * stepSize_V;
            float aerosolDensityAtPos_V = exp(-height_V / H_Aerosols) * stepSize_V;

            densityAir_V += airDensityAtPos_V;
            densityAerosols_V += aerosolDensityAtPos_V;

            // Ray setup -> Sun ray
            vec3 densityAir_S = vec3(0.0);
            vec3 densityAerosols_S = vec3(0.0);
            float t0_S = 0.0;
            float t1_S = 0.0;

            // Atmosphere intersection -> Sun ray
            RayIntersectSphere(pos_V, sunDir, vec3(0.0), R_atmo, t0_S, t1_S);

            // Raymarching from point in view ray -> sunDir
            float t_S = 0.0;
            float stepSize_S = t1_S / float(numSamples_S);
            bool hitGround = false;

            for (int i = 0; i < numSamples_S; ++i)
            {
                vec3 pos_S = pos_V + sunDir * (t_S + stepSize_S * 0.5);
                float height_S = length(pos_S) - R_earth;
                if (height_S < 0.)
                {
                    hitGround = true;
                    break;
                }

                densityAir_S += exp(-height_S / H_Air) * stepSize_S;
                densityAerosols_S += exp(-height_S / H_Aerosols) * stepSize_S;

                t_S += stepSize_S;
            }

            // Earth shadow
            if (!hitGround)
            {
                // Multiplication of exponentials == sum of exponents
                vec3 tau = betaRayleigh * (densityAir_V);
                tau += betaMie * 1.1 * (densityAerosols_S + densityAerosols_V);
                vec3 transmittance = exp(-tau);

                // Total scattering from both view and sun ray direction up to this
                // point
                totalRayleigh += airDensityAtPos_V * transmittance;
                totalMie += aerosolDensityAtPos_V * transmittance;
            }

            t_V += stepSize_V;
        }
    }
    return S_Luminance * (totalRayleigh * phaseRayleigh * betaRayleigh +
                          totalMie * phaseMie * betaMie);
}

mat3 
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 temp = normalize(vec3(sin(roll), cos(roll), 0.0));

    vec3 k = normalize(target - eye);
    vec3 i = normalize(cross(temp, k));
    vec3 j = cross(k, i);

    return mat3(i, j, k);
}

#define INV_GAMMA 0.454545
void 
mainImage(out vec4 fragcolor, in vec2 fragCoord)
{
    // Init common vars
    time = iTime / 20.0;
#if 1
    sunDir = normalize(vec3(1.0, -0.03, 0.0));
#else
    sunDir = normalize(vec3(sin(time), abs(cos(time)) - 0.0, 0.0));
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

#else
    // Pinhole cam pointing east
    vec3 ta = ro + vec3(1.0, 0.0, 0.0);
    const float nearPlane = 1.0;
    mat3 cam = SetCamera(ro, ta, 0.0);
    vec3 rd_WS = cam * normalize(vec3(uv, nearPlane));
#endif

    vec3 col = Render(ro, rd_WS);

    col = pow(col, vec3(INV_GAMMA));
    fragcolor = vec4(col, 1.0);
}