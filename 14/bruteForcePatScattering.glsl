#include "./hashes.glsl"

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

vec3
pointOnSphere(vec3 pos) 
{
    float u = hash11(pos.x);
    float v = hash11(pos.y);

    float theta = u * 2.0 * M_PI;
    float phi = acos(2.0 * v - 1.0);
    float r = pow(hash11(pos.z), 1.0/3.0);

    float sinTheta = sin(theta);
    float cosTheta = cos(theta);

    float sinPhi = sin(phi);
    float cosPhi = cos(phi);

    float x = r * sinPhi * cosTheta;
    float y = r * sinPhi * sinTheta;
    float z = r * cosPhi;

    return normalize(vec3(x, y, z));
}

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
RayIntersectSphere(vec3 ro, vec3 rd, vec3 sOrigin, float r, inout float t0, inout float t1)
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

#define MAX_STEPS_VIEW 16
#define MAX_STEPS_SUN 16
#define MAX_BOUNCES 5
vec3
RenderBruteForce(vec3 ro, vec3 rd, float seed)
{
    //Original ray values
    vec3 oRo  = ro;
    vec3 oRd  = rd;

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
    bool hit = RayIntersectSphere(oRo, oRd, vec3(0.0), R_atmo, t0_V, t1_V);
    if (!hit) return totalRayleigh; // Empty value

    // Calculate the angle between the view ray and the sundirection
    float mu_v = dot(rd, sunDir);

    float phaseRayleigh = 0.0;
    float phaseMie = 0.0;

    // Why only for the angle between view and sun?
    phaseRayleigh = rayleighPhaseFunction(mu_v);
    phaseMie = henyeyGreensteinPhaseFunc(mu_v);

    // Subdivide the view ray into steps
    float stepSize_V = t1_V / float(MAX_STEPS_VIEW);
    float t_V = 0.0;

    //Order zero scattering 
    for (int step_v = 0; step_v < MAX_STEPS_VIEW; ++step_v)
    {
        // Marching along view ray
        vec3 pos_V = oRo + oRd * (t_V + stepSize_V * 0.5);
        float height_V = length(pos_V) - R_earth;

        // Density at current location
        // Why multiply times the step distance?
        float airDensityAtPos_V     = exp(-height_V / H_Air) * stepSize_V;
        float aerosolDensityAtPos_V = exp(-height_V / H_Aerosols) * stepSize_V;

        densityAir_V      += airDensityAtPos_V;
        densityAerosols_V += aerosolDensityAtPos_V;

        // Calculate new ray direction from current pos
        ro = pos_V;
        rd = pointOnSphere(pos_V + hash31(seed));

        // Bounce ray bounds
        float t0_B       = 0.0;
        float t1_B       = 0.0;
        float t_B        = 0.0;
        float stepSize_B = 0.0;

        //Density accumulated along bounces
        vec3 densityAir_B = vec3(0.0);
        vec3 densityAerosols_B = vec3(0.0);

        // For each Bounce
        // We're manually doing bounce 0 (view ray) and 1 (ray to light)
        bool hitGround = false;
        for(int bounce = 2; bounce < MAX_BOUNCES; ++bounce)
        {
            // Calculate ray bounds 
            // by definition we'll never be outside the earth
            RayIntersectSphere(ro, rd, vec3(0.0), R_atmo, t0_B, t1_B);

            // Move ray forward random amount up to the atmosphere exit
            float randStep = hash11(seed + hash11(float(bounce)));
            stepSize_B = pow(randStep, 1.0) * t1_B;

            vec3 pos_B = ro + rd * stepSize_B * 0.5;
            float height_B = length(pos_B) - R_earth;

            // If our height is less than zero it means we have intersected the ground
            // Backtrack and set this bounce start back to sea level
            if (height_B < 0.)
            {
                RayIntersectSphere(ro, rd, vec3(0.0), R_earth, t0_B, t1_B);
                stepSize_B = t0_B * 1.0;
                pos_B = ro + rd * stepSize_B * 0.5;
                height_B = length(pos_B) - R_earth;
            }
            
            // Getting air density at current bounce
            // But what do we do with it?
            float airDensityAtPos_B = exp(-height_B / H_Air) * stepSize_B;
            float aerosolDensityAtPos_B = exp(-height_B / H_Aerosols) * stepSize_B;

            // Can't really add it to the view ray can we?

            //densityAir_B += airDensityAtPos_B;
            //densityAerosols_B += aerosolDensityAtPos_B;

            // Calculate the next bounce direction
            ro = pos_B;
            //rd = pointOnSphere(hash31(seed + fract(7.823 * float(bounce) ) ) );
        }

        // Ray setup -> Sun ray
        vec3 densityAir_S = vec3(0.0);
        vec3 densityAerosols_S = vec3(0.0);
        float t0_S = 0.0;
        float t1_S = 0.0;

        //Calculate order one scattering
        // Atmosphere intersection -> Sun ray
        RayIntersectSphere(ro, sunDir, vec3(0.0), R_atmo, t0_S, t1_S);

        // Raymarching from point in view ray -> sunDir
        float t_S = 0.0;
        float stepSize_S = t1_S / float(MAX_STEPS_SUN);

        for (int i = 0; i < MAX_STEPS_SUN && !hitGround; ++i)
        {
            vec3 pos_S = ro + sunDir * (t_S + stepSize_S * 0.5);
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
            vec3 tau = betaRayleigh * (densityAir_V + densityAir_S + densityAir_B);
            tau += betaMie * 1.1 * (densityAerosols_S + densityAerosols_V + densityAir_B);
            vec3 transmittance = exp(-tau);

            // Total scattering from both view and sun ray direction up to this
            // point
            totalRayleigh += airDensityAtPos_V * transmittance;
            totalMie += aerosolDensityAtPos_V * transmittance;
        }

        //Move along view ray
        t_V += stepSize_V;
        hitGround = false;
    }
    //return vec3(seed);
    return S_Luminance * (totalRayleigh * phaseRayleigh * betaRayleigh +
                          totalMie * phaseMie * betaMie);
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
                vec3 tau = betaRayleigh * (densityAir_V + densityAir_S);
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
    //Random val per pixel per frame
    float seed = hash11(dot(vec2(12.9898, 78.233),fragCoord) + 1113.1*float(iFrame));

    // Init common vars
    time = iTime / 20.0;
    // Fixed/moving sun
#if 1
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

#else
    // Pinhole cam pointing east
    vec3 ta = ro + vec3(1.0, 0.0, 0.0);
    const float nearPlane = 1.0;
    mat3 cam = SetCamera(ro, ta, 0.0);
    vec3 rd_WS = cam * normalize(vec3(uv, nearPlane));
#endif

    vec3 col = vec3(0.0);
    float cutoff = 0.0;
#if 0
    cutoff = sin(time* 20.0);
#endif

    if(uv.x > cutoff)
    {
        col = Render(ro, rd_WS);
    }
    else
    {
        //Averaging
        #define avg 10
        #define ZERO (min(iFrame, 0))
        vec3 temp = vec3(0.0);
        for(int i = ZERO; i < avg; ++i)
        {
            temp += RenderBruteForce(ro, rd_WS, seed);
        }
        //col = temp;
        col = temp / vec3(avg);
        //col = temp / vec3(avg);
    }

    //Vertical line
    col = (abs(uv.x - cutoff) < 0.005) ? vec3(0.0, 1.0, 0.0) : col;

    col = pow(col, vec3(INV_GAMMA));
    fragcolor = vec4(col, 1.0);
}