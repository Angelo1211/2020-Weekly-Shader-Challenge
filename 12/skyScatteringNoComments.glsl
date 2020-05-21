#include "./common.glsl"

//const variables
const float S_Luminance = 20.0;
const float R_earth     = 6360e3;
const float R_atmo      = 6420e3;
const float H_Air       = 7994.0; 
const float H_Aerosols  = 1200.0; 
const vec3 betaRayleigh = vec3(3.8e-6f, 13.5e-6f, 33.1e-6f); 
const vec3 betaMie = vec3(21.0e-6);
const int numSamples_View = 16;
const int numSamples_Sun  = 8;

//uniforms
float time = 0.0;
vec3 sunDir = vec3(0.0);

float
rayleighPhaseFunction(float mu)
{
    return 
           3.0 * (1.0 + mu*mu)
    / //----------------------
            (16.0 * M_PI);
}

float
henyeyGreensteinPhaseFunc(float mu)
{
    const float g = 0.76;
    return
                        (1. - g*g)
    / //---------------------------------------------
        ((4. * M_PI) * pow(1. + g*g - 2.*g*mu, 1.5));
}

bool
RayIntersectSphere(vec3 ro, vec3 rd, vec3 sOrigin, float r, inout float t0, inout float t1)
{
    ro -= sOrigin;
    float A = dot(rd, rd);
    float B = 2.0 * dot(ro, rd);
    float C = dot(ro, ro) - r*r;
    float discriminant = B*B - 4.0*A*C;

    //Ray never hits sphere
    if(discriminant < 0.0) return false;

    t0 = (-B - sqrt(discriminant)) / 2.0*A ;
    t1 = (-B + sqrt(discriminant)) / 2.0*A ;

    return true;
}

vec3
Render(vec3 ro, vec3 rd)
{
    //Ray setup -> view ray
    float t0_View, t1_View;
    vec3 densityAir_View, densityAerosols_View;
    vec3 totalRayleigh, totalMie;

    //Atmosphere intersection -> view ray
    bool hit = RayIntersectSphere(ro, rd, vec3(0.0), R_atmo , t0_View, t1_View);
    if(!hit) return totalRayleigh; //Empty value

    //Phase functions
    float mu = dot(rd, sunDir);
    float phaseRayleigh = rayleighPhaseFunction(mu);
    float phaseMie = henyeyGreensteinPhaseFunc(mu);

    //Ray marching -> view ray
    float stepSize_View = t1_View / float(numSamples_View);
    float t_View = 0.0; 
    for(int i = 0; i < numSamples_View; ++i)
    {
        vec3 pos_View = ro + rd*(t_View + stepSize_View * 0.5);
        float height_View = length(pos_View) - R_earth;

        //Density at current location
        float airDensityAtPos_View = exp(- height_View / H_Air ) * stepSize_View;
        float aerosolDensityAtPos_View = exp(-height_View / H_Aerosols) * stepSize_View;

        densityAir_View += airDensityAtPos_View;
        densityAerosols_View += aerosolDensityAtPos_View;

        //Ray setup -> Sun ray
        vec3 densityAir_Sun, densityAerosols_Sun;
        float t0_Sun, t1_Sun;

        //Atmosphere intersection -> Sun ray
        RayIntersectSphere(pos_View, sunDir, vec3(0.0), R_atmo , t0_Sun, t1_Sun);

        //Raymarching from point in view ray -> sunDir
        float t_Sun = 0.0; 
        float stepSize_Sun = t1_Sun / float(numSamples_Sun);
        bool hitGround = false;
        for(int i =0; i < numSamples_Sun; ++i)
        {
            vec3 pos_Sun = pos_View + sunDir * (t_Sun + stepSize_Sun * 0.5);
            float height_Sun = length(pos_Sun) - R_earth;
            if(height_Sun < 0.)
            {
                 hitGround = true;
                 break;
            }

            densityAir_Sun      += exp(-height_Sun / H_Air)      * stepSize_Sun;
            densityAerosols_Sun += exp(-height_Sun / H_Aerosols) * stepSize_Sun;

            t_Sun += stepSize_Sun;
        }

        //Earth shadow
        if(!hitGround) 
        {
            //Multiplication of exponentials == sum of exponents
            vec3 tau = betaRayleigh * (densityAir_View);
            tau += betaMie * 1.1 * (densityAerosols_Sun + densityAerosols_View); 
            vec3 transmittance = exp(-tau);

            //Total scattering from both view and sun ray direction up to this point
            totalRayleigh += airDensityAtPos_View * transmittance;
            totalMie      += aerosolDensityAtPos_View * transmittance;
        }

        t_View += stepSize_View;
    }

    //return S_Luminance * ( phaseRayleigh * vec3(0.1));
    return S_Luminance * (totalRayleigh * phaseRayleigh * betaRayleigh + totalMie * phaseMie * betaMie );
}

void 
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Init common vars
    time = iTime / 10.0;
    sunDir = normalize(vec3(sin(time), abs(cos(time)) - 0.2, 0.0));

    const bool fishEye = true;
    const bool mouseControl = false;

    if(mouseControl)
        sunDir = normalize(vec3(iMouse.xy,0.0));
    
    vec3 col = vec3(0.0);

    //Common Camera setup
    vec3 rayOrigin = vec3(0, R_earth + 1.0 , 0.0);
    vec2 uv = 2.0 *  (fragCoord - 0.5*iResolution.xy) / iResolution.y;

    vec3 rayDirection_WS;
    //if(fishEye && iMouse.z < 0.1)
    if(fishEye)
    {
        //Fisheye camera
        const float hemisphereRadius = 1.0;
        float length2 = dot(uv, uv);
        if(length2 > hemisphereRadius) return;
        float phi = atan(uv.y, uv.x); 
        float theta = acos(sqrt((hemisphereRadius - length2)));
        rayDirection_WS = vec3(sin(theta) * cos(phi),
                           cos(theta),
                           -sin(theta) * sin(phi));
    }
    else
    {
        //Pinhole camera
        vec3 target = rayOrigin + vec3(1.0, 0.0, 0.0);
        const float nearPlane = 1.0;
        rayDirection_WS = SetCamera(rayOrigin, target, 0.0) * normalize(vec3(uv, nearPlane));
    }

    col = Render(rayOrigin, rayDirection_WS);

    GAMMA(col);
    fragColor = vec4(col, 1.0);
}
