#include "./common.glsl"
/*
    Reading this today:
    https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/simulating-sky/simulating-colors-of-the-sky
*/

//const variables
const float R_earth = 6360e3;
const float R_atmo  = 6420e3;

//uniforms
float time = 0.0;

//https://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-sphere-intersection
bool
RayIntersectSphere(vec3 ro, vec3 rd, vec3 sOrigin, float r, inout float t0, inout float t1)
{
    //Radius to sphere center
    vec3 rc = sOrigin - ro; 

    //Distance to closest point to center along ray
    float tca = dot(rc, rd);

    //If negative it means the intersection ocurred behind the ray, don't care about that 
    if (tca < 0.0) return false;

    //Shortest distance from the center to the ray
    float d2 = dot(rc, rc) - tca * tca; 

    //If the shortest distance from the center to the ray is larger than the radius you missed the sphere
    float r2 = r*r;
    if (d2 > r2) return false; 

    //We hit the sphere, update the points where we hit it
    float thc = sqrt(r2 - d2); 
    t0 = tca - thc; 
    t1 = tca + thc; 

    return true;
}

vec3
Render(vec3 ro, vec3 rd)
{
    //Ray setup
    float t0, t1;
    vec3 col;

    if (RayIntersectSphere(ro, rd, vec3(0.0), R_atmo , t0, t1)) {col = vec3(1.0, 0.0, 0.0);}
        
    return col;
}

void 
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Init common vars
    const float domeRadius = 1.0;
    vec3 col = vec3(0.0);
    time = iTime / 10.0;
    
    /*
        1) Moving the origin to the center of the screen not the lower left corner
        2) Aspect ratio correction to make y be of length 1 and go from [-0.5,0.5]
        3) Changing that to [-1.0. 1.0] because x^2 = x at 1.0, comes in handy later
    */
    vec2 uv = 2.0 * (fragCoord - 0.5*iResolution.xy) / iResolution.y;

    //We now have a cartesian plane with all points having a z = 0.0. 
    //Not what we want long term
    vec3 p = vec3(uv, 0.0);

    //Spherical Coordinates
    // dotproduct(a, b) = a.x * b.x + a.y * b.y;
    // dotproduct(a, a) = a.x * a.x + a.y * a.y;
    // length = sqrt(x^2 + y^2)
    // length^2 = dot(a, a)
    float length2 = dot(uv,uv);

    //Setting our ray Origin one meter above earth surface
    vec3 ro = vec3(0, R_earth + 1.0, 0.0 );

    //Now is where that remapping to [-1,1] in y comes in handy
    if(length2 <= domeRadius)
    {
        // tan(phi) = opposite/adjacent
        float phi = atan(uv.y, uv.x); 

        /*
            Radius^2 = height^2 + length^2
            Cos(theta) = adj / hyp
            cos(theta) = height/radius
            radius = 1.0
            theta = acos(height)
                  = acos(sqrt(1.0 - length^2))
            Scratchapixel uses acos(1.0 - length^2) but I don't think that's corrrect 
            since  Radius^2 = height^2 + length^2 and we need to solve for height we should use
                  = acos(sqrt(1.0 - length^2))
            We assume the dome radius is 1.0 for simplicity
        */
        float theta = acos(sqrt(domeRadius - length2));

        //Getting a ray direction 
        //Y is up?
        vec3 rd = vec3( sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi) );


        col = vec3(theta);
    }

    GAMMA(col);
    fragColor = vec4(col, 1.0);
}