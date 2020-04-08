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

    vec3 ro = vec3(0, 0.0, R_earth + 1.0 );

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

        /*
            We can construct the cartesian vector from the spherical coords by using:
            the following: 
            vec3 original = vec3(sin(theta) * cos(phi),
                                 sin(theta) * sin(phi),
                                 cos(theta));
            The derivation from this is as follows, change of height in hemisphere
            occurrs in the z direction, is constant in y or x. So we know that the 

            *height = r cos z*;
            *then the xy plane shares r sin z*
            *r = 1.0*
            *in the plane theta = 90 so sin(theta) 1*
            *you know phi = 0 when x = 0 so it must be cos for x*
            *same logic for using sin for y*

            This leaves us with:
                x: right-left (hemi base)
                y: up-down    (hemi base)
                z: in-out     (hemi cap)
            Which is a right-handed coordinate system

            To check for handedness this is the only consistent way I have found:
                1) Realize that handedness is determined by the result of cross products
                2) In a right handed system ixj = k
                3) Use the way your fingers naturally curl inwards to curl them from i->j
                4) The thumb now points in the direction of k (or z in our case)

            What we want:
                x: right-left (hemi base)
                y: up-down    (hemi cap)
                z: in-out     (hemi base)
            We want to maintain the right handedness of the system
            but want to rotate z with y

            The origina code did the following:
                vec3 desired = vec3(sin(theta) * cos(phi),
                                    cos(theta),
                                    sin(theta) * sin(phi));

            This is wrong! Or atleast not what I wanted, it makes
            the coordinate system become left-handed by switching
            z with y, literally! We want to rotate but not just switch them since this will
            mess up the handedness

            What we need to do is Rotate the hemisphere -90deg in x
            Draw it out so you see why it's negative

            *Insert explanation of how to derive rotation vector*
              i j k 
            [ 1 0 0 ]
            [ 0 0 0 ]
            [ 0 0 0 ]
            *Explain that we know this is only for 90 so can precalculate*

            *Explain that a negative needs to be inserted for correctness*

            *got it*
        */


        float ang = -M_PI / 2.0;
        mat3 xRot = mat3(vec3(1,        0,         0),
                         vec3(0, cos(ang), -sin(ang)),
                         vec3(0, sin(ang), cos(ang)));
        //rd_new = rd_new * (xRot);
        //rd_new.y = -rd_new.y; switch y if you are right handed
        //rd_new.z = -rd_new.z;

        //col = original;
        col = desired;

    }

    GAMMA(col);
    fragColor = vec4(col, 1.0);
}

        /*
            Shouldn't this be the same?!?!
            col = vec3(sin(theta), 0.0, 0.0);
            col = vec3(sin(theta), cos(theta), 0.0) * vec3(1, 0, 0);
        */