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
        
    if (RayIntersectSphere(ro, rd, vec3(0.0), R_atmo , t0, t1)) {col = vec3(0.0, 1.0, 0.0);}
        

    return col;
}

void 
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //AR corrected and going from -1 to 1 in the y
    vec2 uv = 2.0 *(((fragCoord) - 0.5*iResolution.xy)/iResolution.y);

    //Step 0: Calculate position
    vec3 p = vec3(uv, 0.0);

    //Init common vars
    vec3 col = vec3(0.0);

    //Spherical Coordinates
    // dotproduct(a, b) = a.x * b.x + a.y * b.y;
    // dotprocut(a, a) = a.x * a.x + a.y * a.y;
    // length = sqrt(x^2 + y^2)
    // length^2 = dot(a, a)
    float r2 = dot(uv,uv);

    // tan(phi) = opposite/adjacent
    float phi = atan(uv.y, uv.x); 


    //Dotproduct(a, b) = |a| * |b| * cos(ang)
    //Dotproduct(a, a) = |a| * |a| * cos(ang)
    //r2 = |a| * |a| 
    float theta = acos(1.0 - r2);

    //Step 1: Show cartesian position
    //col = p;

    //Step 2: Limit to drawing only in position with radius < 1.0
    //if(r2 < 1.0 && p.y > 0.0)
    //if(r2 < 1.0 && r2 > 0.99 )
    if(r2 < 1.0)
    {
        //Step 3: Show phi
        col = vec3(phi);

        //Step 4: Show theta
        col = vec3(theta);

        col = vec3(1.0);
    }

    GAMMA(col);
    fragColor = vec4(col, 1.0);
}

/*

    //One meter above earth surface
    vec3 ro = vec3(0, R_earth + 1.0, 0.0 );
    //Theta is zero at the edges of the dome so 1.0 - z2 gives us the radius
    //float theta = (z2);
    time = iTime / 10.0;
    //Spherical to cartesian coordinates
    //Y is up?
    /*
    vec3 rd = vec3(sin(theta) * cos(phi),
                   cos(theta),
                   sin(theta) * sin(phi)
                   );
        //col = Render(ro, rd);
        //col += vec3(rd);
        //col = vec3(uv, 0.0);
        //col = vec3(z2);
        //col = vec3(theta);
*/