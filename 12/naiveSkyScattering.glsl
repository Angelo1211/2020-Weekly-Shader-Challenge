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
    vec3 col = vec3(0.0);
    time = iTime / 10.0;

    /*
        Let's begin by defining some properties of our world.
        1) Our worldspace coordinates will think of Y as up.
        2) The earth's center shall be located at the origin of our coordinate system
        3) The camera will be positioned at 1 meter above the earth in one of it's poles.
        4) The camera will point towards y and encompass the whole visible sky

        Hence our ray origin will be located at the following worldspace coordinates:
    */
    vec3 ro = vec3(0,  R_earth + 1.0 , 0.0 );
    
    /*
        We've taken care of the first 3 properties with the above line but it's gonna take a lot 
        more work to get to the 4th one. Let's move away from worldspace coordinates for now and 
        build the camera in screen space first, then position it and point in world space once done. 
        We're going to build the basic coordinate sytem for our shader here.
        1) Moving the origin to the center of the screen from the lower left corner
        2) Aspect ratio correction to make y be of length 1 and go from [-0.5,0.5]
        3) Changing that to [-1.0. 1.0] because x^2 = x at 1.0, comes in handy later.
    */
    vec2 uv = 2.0 * (fragCoord - 0.5*iResolution.xy) / iResolution.y;

    /*
        Our goal here is to perform ray tracing along a hemisphere to capture the full 180deg of sky.
        To do this we're going to construct a hemisphere and sample the surface with every pixel. This is
        known as a fish-eye lens camera.
        We'll begin by building a cartesian plane with all points having a z = 0.0. 
    */
    vec3 p = vec3(uv, 0.0);

    /*
        Our goal is to construct a hemisphere with it's base aligned with the xy plane and the height 
        in z. This will make the construction easy but the rendering somewhat harder. The base will be a radius
        1 circle. Building this circle is straightforward, we evaluate the distance of each pixel to the center
        of the screen (which is 0,0 in the coordinate sytem we built above).

        We'll keep the length squared since it'll save us an unecessary sqrt
        Spherical Coordinates
            dotproduct(a, b) = a.x * b.x + a.y * b.y + a.z * b.z;
            dotproduct(a, a) = a.x * a.x + a.y * a.y + a.z * a.z;
            length = sqrt(x^2 + y^2 +z^2)
            length^2 = dot(a, a)
    */
    float length2 = dot(p, p);

    /*
        To build a circle we skip work for all pixels that are not in a unit circle.
        Here's where that remapping to [-1,1] in y comes in handy.
        This gives us the "base" of the hemisphere camera lens.
    */
    const float hemisphereRadius = 1.0;
    if(length2 <= hemisphereRadius)
    {
        /*
            Building a hemisphere is easier in spherical coordinates so we're going to transform our cartesian
            coords to spherical step by step. Spherical coordinates are defined with three component too:
                A radius R (1.0 in our case)
                Zenith angle Theta [0, PI]
                Azimuth angle Phi [0, 2PI]
                Represented as (R, theta, phi)
            We've defined R ourselves to be one. next we shall obtain phi. Now, depending where you search for 
            info on this, they might call this angle theta. I'm going with the wikipedia convention for physics
            as seen here: https://en.wikipedia.org/wiki/Spherical_coordinate_system
            We get phi like so: 
                tan(ang) = opposite / adjacent
                tan(phi) = y / x
            [1] phi = atan(y, x) (using atan2 syntax since it avoids negative ambiguities)
        */
        float phi = atan(uv.y, uv.x); 

        /*
            Lastly we need the zenith angle theta to complete our hemisphere in spherical coords.
            To do this we need the radius R we established earlier for circle in the base and we'll
            re-use the same radius for the spherical cap. 

            Height
            ^         R
            |       / 
            |     / 
            |   / 
            | /
            0-----------> Length

            This is my best attempt at an ASCII diagram of how to obtain the angle theta, which is the angle
            that covers the space between Z and R. Remember, we have already obtained the length^2 from the 
            base of the circle.
            We'll obtain theta like so:
                Radius^2   = height^2 + length^2
            [1] height     = sqrt(R^2 - L^2)
                Cos(ang)   = adj / hyp
                cos(theta) = height/radius
                theta = acos(height/radius)
                    (in our case R = 1.0)
                theta = acos(height)
            [2] theta = acos(sqrt(1.0 - length^2))

            Scratchapixel uses acos(1.0 - length^2) but I don't think that's correct, as seen above.
                -Adding this fixes the weird permanent sunset at the edges of their model
        */
        float theta = acos((hemisphereRadius - length2));

        /*
            We have now constructed a vector in spherical coordinates for each pixel over the surface
            of the hemisphere cap. For rendering we will want this vector represented using cartesian
            coordinates. Remember that we had defined our original cartesian system where we built the
            circle with +X to the right of the screen (parallel to the screen width) and +Y going upwards
            (parallel to the screen height). So, since the base was aligned with the XY plane
            the height of the hemisphere must be aligned with Z. With this information we have enough
            to calculate the Z coordinate of our hemisphere surface vector:
            
            Height = Z component
            Height = R * cos(theta)
            Z = R * cos(theta)
            (Radius = 1.0)
        [1] Z = cos(theta)

            X and Y can be obtained by realizing that the remaining length of the vector: R sin(theta)
            will result in the projection of the hemisphere vector on the XY plane. From then on we can
            reason about how to obtain transformations for X and Y by thinking about how phi behaves when
            we're on X or on Y.  This will allows us to break down that projection even further into
            its contribution on each axis.

            For X:
            Cartesian: (1, 0, 0) (X, Y ,Z)
            Spherical: (1, 90deg, 0deg) (R, theta, phi)
            X = sin(theta) * ?(phi)
            (Substituting for X, theta, phi)
                1 = sin(90deg) * ?(0)
                1 = 1 * ?(0)
                ? = cos
                (Since cos(0) = 1)
        [2] X = sin(theta) * cos(phi)

            Repeating the process for Y:
            Cartesian: (0, 1, 0) (X, Y ,Z)
            Spherical: (1, 90deg, 90deg) (R, theta, phi)
            Y = sin(theta) * ?(phi)
            (Substituting for Y, theta, phi)
                1 = sin(90deg) * ?(90deg)
                1 = 1 * ?(90deg)
                ? = sin
                (Since sin(90deg) = 1)
        [3] Y = sin(theta) * sin(phi)
        
        Putting it all together:
        */
        vec3 hemisphereSurface = vec3(sin(theta) * cos(phi),
                                      sin(theta) * sin(phi),
                                      cos(theta));

        /*
            This leaves us with:
                +x: hemi base
                +y: hemi base
                +z: hemi cap
            
            At this point I started wondering if we were in a left handed or a right handed 
            coordinate system. As far as I can tell, it is ambiguous at this moment. Throughout
            our hemisphere construction we have not performed any operation that would determine
            handedness. So all of the math we did up to now would result in the same vectors
            components in both left or right handed coordinate systems.
            
            All we know for sure is that the hemisphere base is in the XY plane, +X points to the
            right parallel to the screen width, +Y points up parallel to the height and +Z is 
            where the hemisphere cap resides, yet not if it points into or out of the screen - 
            only that it is perpendicular to the XY plane.

            In the process of reasoning about this I have found a consistent way to determine if
            your coordinate system is left handed or right handed:
                1) Realize that handedness determines the result of cross products
                2) I want my cross products to behave as expected 
                3) In a right handed system ixj = +k, jxk = +i, kxi= +j 
                         i
                        / \
                       /   \
                      k-----j
                4) Use the way your fingers naturally curl inwards to curl them from i->j
                5) The thumb now points in the direction of k (z in our case)
            
            Now, we can resolve this ambiguity with more information. Let's start by specifying 
            the world-space coordinates
            by specifying our world-space coordinates, the 
            direction we want our camera to point in and in which space we had  

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

        vec3 rd_new = hemisphereSurface;
        //rd_new.z *= -1.0;

        vec3 desired = vec3(sin(theta) * cos(phi),
                            cos(theta),
                            sin(theta) * sin(phi));

        float ang = -M_PI / 2.0;
        //float ang = M_PI;
        mat3 xRot = mat3(1,        0,         0,
                         0, cos(ang), -sin(ang),
                         0, sin(ang), cos(ang));
        //rd_new = (xRot) * rd_new ;
        //rd_new = transpose(xRot) * rd_new ;
        //rd_new = xRot * rd_new ;
        //rd_new.y *= -1.0;

        // mat3 xRot90 = mat3(vec3(1, 0, 0),
        //                    vec3(0, 0, 1),
        //                    vec3(0, -1,0));

        //rd_new = rd_new * xRot  ;
        //rd_new.y = -rd_new.y; switch y if you are right handed
        //rd_new.z = -rd_new.z;

        //col = abs(rd_new);
        col = (rd_new);
        //if(uv.x > 0.2)
            //col = desired;

        //col = rd_new;
        //col = desired;
        //col = original;
        //col = p;
        //col = vec3(phi);
        //col = vec3(uv, 0.0);
        //col = vec3(length2);

        //vec3 ro = vec3(0, 0.0, R_earth + 1.0 );
    }

    GAMMA(col);
    fragColor = vec4(col, 1.0);
}

        /*
            Shouldn't this be the same?!?!
            col = vec3(sin(theta), 0.0, 0.0);
            col = vec3(sin(theta), cos(theta), 0.0) * vec3(1, 0, 0);
        */