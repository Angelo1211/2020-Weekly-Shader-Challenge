
#include "./common.glsl"

//const variables
const float R_earth = 6360e3;
const float R_atmo  = 6420e3;

//uniforms
float time = 0.0;

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
    //Ray setup
    float t0, t1;
    vec3 col;

    //Atmosphere intersection
    if (RayIntersectSphere(ro, rd, vec3(0.0), R_atmo , t0, t1)) {col = vec3(1.0, 0.0, 0.0);}
        
    return col;
}

void 
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Init common vars
    vec3 col = vec3(0.0);
    time = iTime / 10.0;

    //Camera setup
    vec3 rayOrigin = vec3(0,  R_earth + 1.0 , 0.0 );
    vec2 uv = 2.0 *  (fragCoord - 0.5*iResolution.xy) / iResolution.y;

    float length2 = dot(uv, uv);
    const float hemisphereRadius = 1.0;
    if(length2 > hemisphereRadius)
    {
        fragColor = vec4(0.0);
        return;
    }

    float phi = atan(uv.y, uv.x); 
    float theta = acos(sqrt((hemisphereRadius - length2)));

    vec3 rayDirection = vec3(sin(theta) * cos(phi),
                            -cos(theta),
                             sin(theta) * sin(phi));
        
    
    col = Render(rayOrigin, rayDirection);

    GAMMA(col);
    fragColor = vec4(col, 1.0);
}
