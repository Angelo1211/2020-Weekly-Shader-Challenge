#include "./common.glsl"

//const variables taken from:
//https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/simulating-sky/simulating-colors-of-the-sky
const float R_earth = 6360e3; //Lengths in meters
const float R_atmo  = 6420e3;
const float H_Air   = 7994.0; 
const float H_Aerosols = 1200.0; 
const vec3 betaR = vec3(3.8e-6, 13.5e-6, 33.1e-6); // Rayleigh 
const vec3 betaM = vec3(21e-6); // Mie

//uniforms
float time = 0.0;
vec3 sunDir = vec3(0.0); //Worldspace

//https://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-sphere-intersection
bool
RayIntersectSphere(vec3 ro, vec3 rd, vec3 sOrigin, float r, inout float t0, inout float t1)
{
#if 1
    //Algebra solution

    /*  Equation of a sphere
        x^2 + y^2 + z^2 = R^2

        Equation of a ray
        p = ro + t*rd 
            t: [0, inf)
        
        A point
        p = (x, y, z)

        Joining point with sphere
        p^2 - R^2 = 0.0
        This equation is true for any point that is on the surface of a sphere

        If the sphere is not in the center of the coordinate system we can offset it by the
        distance of the center to the origin and now have all points relative to the center 
        of the sphere instead of relative to the coordinate system origin.
    [1] (p - cen)^2 - R^2 = 0.0

        We want to check if the above equation is true for any point on a ray and we can do so
        by substituting the equation of a ray into eq [1] like so:
        (ro + t*rd - cen)^2 - R^2 = 0.0

        Simplifying a bit we get:
        t^2*rd^2 + 2.0*(ro-cen)*t*rd + (ro - cen)^2 - R^2 = 0.0

        Which is a quadratic equation if we focus only on t:
        A*t^2 + B*t + C = 0.0
        Where:
        A = rd^2
        B = 2.0 * (ro - cen) * rd
        C = (ro - cen)^2 - R^2

        As we know quadratic equations can be solved using:
            -B +- sqrt(b^2 - 4ac)
        ----------------------------
                    2*a
        
        The discriminant:
            B^2 - 4AC
        Tells us the following about the code:
            A positive discriminant means there are two distinct intersection points
            A discriminat of zero means there's only one result
            A negative means no answer

        We start by subtracting the sphere origin and then calculate the above as follows:
    */
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
#else
    //Geometric solution
    //Radius to sphere center
    vec3 rc = sOrigin - ro; 

    //Distance to closest point to center along ray
    float tca = dot(rc, rd);

    /*
    //If negative it means the intersection ocurred behind the ray, 
    //If you're inside the sphere one one of the points might be negative
    //so we don't want to early out just yet.
    if (tca < 0.0) return false;
    */

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

#endif
}

//From literature
float
rayleighPhaseFunction(float mu)
{
    return 
          3.0 * (1.0 + mu*mu)
    / //----------------------
            (16.0 * M_PI);
}

//From literature
float henyeyGreensteinPhaseFunc(float mu)
{
    const float g = 0.76;
#if 1
    return    
                 3.0  * ((1.0 - g*g) * (1.0 + mu*mu))
       / //------------------------------------------------
       (8.0*M_PI) * ((2.0 + g*g) * pow(1.0 + g*g - 2.0*g*mu, 1.5)); 

#else
	return
						(1. - g*g)
	/ //---------------------------------------------
		((8. * M_PI) * pow(1. + g*g - 2.*g*mu, 1.5));
#endif
}

/*
    Also raymarching but towards the light
*/
bool
RayMarchTowardsLight(in vec3 ro, in vec3 rd, inout float densityRayleigh, inout float densityMie)
{

    /*
        Check if the ray intersects with the atmosphere but now going towards the light
    */
    float t0, t1;
    RayIntersectSphere(ro, rd, vec3(0.0), R_atmo , t0, t1);


	float t = 0.;
    float numSamples = 8.0;
	float stepSize = t1 / numSamples;

	for (int i = 0; i < int(numSamples); i++)
    {
        //New position along view pos to light ray
		vec3 pos = ro + rd * (t + 0.5 * stepSize);

        //Checking if the ray intersects with the ground (and hence is in shadow)
		float height = length(pos) - R_earth;
		if (height < 0.) return false; 

		densityRayleigh += exp(-height / H_Air) * stepSize;
		densityMie += exp(-height / H_Aerosols) * stepSize;

        //Marching along ray
		t += stepSize;
	}
    return true;
}

vec3
Render(vec3 ro, vec3 rd)
{
    //SKYRENDERING
    /*
        Ray setup
        First and second intersection point, if you're inside the sphere the first intersection
        point will be negative. We don't care about the negative intersection point since that
        will be located behind the ray origin.
    */
    float t0, t1; 

    /*
        //Ray-Atmosphere intersection
        The first thing we do is check if any of our rays intersect with the atmosphere
        and if so at what point(s). Although our demo is fairly static and looking from 
        the gorund up only for now the model allows for looking at the sky from outside 
        the planet too so this is definitely something we want to check for no matter what.
    */
    RayIntersectSphere(ro, rd, vec3(0.0), R_atmo , t0, t1);

    /*
        //Determining step size

        We also need the intersection point to determine the stepsize in our raymarcher.
        We're doing a fixed number of steps (16) but the segment from the ray origin to the 
        atmosphere exit point might be a different length depending on the height to the ground
        and the current angle of inclination of the sun.
    */
    const float numSamples = 16.0;
    float stepSize = t1 / float(numSamples);

    /*
        Cosine of angle between view and sun direction
        dot(a, b) = |a| |b| cos(ang)

    [1] cos(ang) = dot(a,b)
                  ----------
                   |a| |b|
    */
    float mu = dot(rd, sunDir);

    /*
        As light travels throughout a participating medium it will interact many times along
        its path with the media. In each interaction the light has a chance for one of the following
        things to occur: 
            1) It can be redirected into moving in a different direction than it's original path.
               An event we refer to as "Out-Scattering"
            2) It can be absorbed during the interaction and transformed into other types of energy
               AKA an "Absorption" event
        
        These two events result in a decrease of the incoming radiance but we can recover some 
        energy by taking into account these following two other events:
            1) Incoming light from other rays that interact with the view ray and sactter into it
                AKA "In-scattering"
            2) The media itself radiates light through chemical/radiation events
                AKA "Emmission"
        
        We will not be taking into account the second event, since the sky is fairly rarely on fire
        (although it doe emit light due to insane pressures during atmospheric re-entry) and this
        model only consider In-scattering.

        The atmosphere surrounding the earth is a participating media composed of many different
        size particles. For this model we consider two major particle groups only. Air, which is 
        made of molecules significantly smaller than the wavelengths of the incoming light, 
        and aerosols, which are particles of about the same size as the light wavelength.

        Light scattering from small air molecules is known as rayleigh scattering while scattering
        from larger particles is known as mie scattering. Rayleigh scattering is highly wavelength
        dependent, while Mie is not.

        Rayleigh Scattering:
            This is the scattering of the light caused by air molecules which are smaller than
            10% of the wavelength of visible light. Total Rayleigh scattering depends on 
            density of air molecules and wavelength of incident light. Light is scattered in 
            nearly all incoming directions in equal manner. Falls at angles close to pi/2.
            This is what is responsible for hte blue color of the sky.

        Mie Scattering:
            Scattering of light caused by aerosols, that is particles larger or equal to 10% of 
            visible light. Aerosols are very strongly forward scattered. 
            This is what is responsible for the white haze around the sun

        *Derive the scattering equation here*
        *What is the range of scattering 0 -1 ?*
        *What is it even unit-wise*
    */
    vec3 totalRayleigh = vec3(0.0);
    vec3 totalMie = vec3(0.0);

    /*
        The phase function is what gives us the proportion of light that is scattered into 
        a ray from a given angle. 

        RTR puts it as follows:
            The phase function is expressed using the parameter theta as the angle between
            the light forward travel path and the path towards the camera.
        Notice how we've got two types of phase functions as well as two types of scattering here
        Mie and Rayleigh scattering. The scattering coefficient combined with the phase function
        describe the proportion of incident light scattered in a given direction.

    */
    float phaseRayleigh = rayleighPhaseFunction(mu);
    float phaseMie = henyeyGreensteinPhaseFunc(mu);

    /*
        Will hold average density along the view ray for air and aerosol particles
    */
    vec3 totalDensityAir = vec3(0.0);
    vec3 totalDensityAerosols = vec3(0.0);

    //Holds current distance travelled along the view ray
    float currentT = 0.0; 
    for(int i =0; i < int(numSamples); ++i)
    {
        /*
            Evaluating our lighting contribution at the middle point
        */
        vec3 pos = ro + rd *(currentT + stepSize * 0.5);

        //Height to the surface of the earth
        float height = length(pos) - R_earth;

        //Calculating the density at this given position
        /*
            EXPLAIN:
            Why are we multiplying by the stepsize?
            Is this just a multiplyer for 
        */
        float heightAir      = exp(-height / H_Air) * stepSize;
        float heightAerosols = exp(-height / H_Aerosols) * stepSize;

        /*
            EXPLAIN
            Why are we aadding height to density?!
        */
        totalDensityAir      += heightAir;
        totalDensityAerosols += heightAerosols;

        /*
            EXPLAIN
        */
        float lightRayleigh = 0.0;
        float lightMie      = 0.0;

        /*
            This retuns true if the sun is over the horizon or not
        */
        if(RayMarchTowardsLight(pos, sunDir, lightRayleigh, lightMie))
        {
            //Calculating transmittance here
            vec3 tau = betaR       * (lightRayleigh + totalDensityAir);
            tau     += betaM * 1.1 * (lightMie      + totalDensityAerosols);
            vec3 transmittance = exp(-tau);

            //If you're above the horizon add light? transmittance?
            //Wtf are these units
            totalRayleigh += heightAir      * transmittance;
            totalMie      += heightAerosols * transmittance;
        }

        //March along the ray
        currentT += stepSize;
    }

    const float sun = 20.0;

    return sun * (totalRayleigh * phaseRayleigh * betaR + totalMie * phaseMie * betaM );
}

void 
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //Init common vars
    vec3 col = vec3(0.0);
    time = iTime / 3.0;

    /*
        INTRO
        Let's begin by defining some properties of our world.
        1) Our worldspace coordinates will think of Y as up.
        2) The earth's center shall be located at the origin of our coordinate system
        3) The camera will be positioned at 1 meter above the earth in one of it's poles.
        4) The camera will point towards y and encompass the whole visible sky

        Hence our ray origin will be located at the following worldspace coordinates:
    */
    vec3 rayOrigin = vec3(0,  R_earth + 1.0 , 0.0 );
    
    /*
        We've taken care of the first 3 properties with the above line but it's gonna take a lot 
        more work to get to the 4th one. Let's move away from worldspace coordinates for now and 
        build the camera in screen space first, then construct all of the rays in camera space.
        Then lastly position it and point in world space once done. 
        
        Moving from screen-space to NDC space
        1) Moving the origin to the center of the screen from the lower left corner
        2) Aspect ratio correction to make y be of length 1 and go from [-0.5,0.5]
        3) Changing that to [-1.0. 1.0] because x^2 = x at 1.0, comes in handy later.
    */
    vec2 uv = 2.0 *  (fragCoord - 0.5*iResolution.xy) / iResolution.y;

    /*
        Our goal here is to perform ray tracing view the film surface shaped like a 
        a hemisphere to capture the full 180deg of sky. To do this we obviously first need
        to construct a hemisphere and sample that surface with a different ray for every pixel.
        This is otherwise known as a fish-eye lens camera.

        We choose (rather arbitrarily) that the base is aligned with the xy plane and the
        height changes in z. The base will be a radius 1 circle. Building this circle is
        straightforward, we evaluate the distance of each pixel to the center of the screen 
        (which is 0,0 in the coordinate sytem we built above).

        We'll keep the length squared since it'll save us a sqrt further ahead.

        dotproduct(a, b) = a.x * b.x + a.y * b.y + a.z * b.z;
        dotproduct(a, a) = a.x * a.x + a.y * a.y + a.z * a.z;
        length = sqrt(x^2 + y^2 +z^2)
    [1] length^2 = dot(a, a)
    */
    float length2 = dot(uv, uv);

    /*
        We build the base circle by simply saying we don't want to render any pixels
        which have a length larger than 1.0 (our radius) Here's where that remapping 
        from [0.5, 0.5] to [-1,1] in y comes in handy.
    */
    const float hemisphereRadius = 1.0;
    if(length2 > hemisphereRadius) return;

    /*
        Building a hemisphere is easier in spherical coordinates. So, we're going to transform
        our cartesian coords P to spherical step by step.

        Spherical coordinates are defined with three components too:
            R: A radius           [0, 1.0]  (could be any value, picked 1.0 for simplicity)
            Theta: Zenith angle   [0,  PI]
            Phi: Azimuth angle    [0, 2PI]
            Represented as a 3 component vector: (R, theta, phi)

        Now, depending where you search for info on this, phi might actually be called theta
        and viceversa. For clarification I'm going to stay with the wikipedia convention for 
        physics as seen here: https://en.wikipedia.org/wiki/Spherical_coordinate_system

        We get phi like so: 
            tan(ang) = opposite / adjacent
            tan(phi) = y / x
        [1] phi = atan(y, x) (using atan2 syntax since it avoids negative ambiguities)
    */

    float phi = atan(uv.y, uv.x); 
    /*
        Lastly we need the zenith angle theta to complete our hemisphere in spherical coords.
        We'll need the radius R we established earlier for the the base and re-use it as the 
        radius for the spherical cap. 

        Height
        ^         R
        |       / 
        |     / 
        |   / 
        | /
        0-----------> Length

        This ASCII diagram shows the hemisphere side-on with the base on the x-axis of the plost
        and the height on the y. You can see that to obtain the angle theta (which here is the angle
        that covers the space between the Height and R) we must use R and the Length. Remember, we
        have already obtained the length^2 from the  base of the circle.

        So theta is obtained like so:
            radius^2   = height^2 + length^2
        [1] height     = sqrt(R^2 - L^2)
            cos(ang)   = adj / hyp
            cos(theta) = height/radius
            theta = acos(height/radius)
                (in our case R = 1.0)
            theta = acos(height)
        [2] theta = acos(sqrt(1.0 - length^2))

        Scratchapixel uses acos(1.0 - length^2) but I don't think that's correct, as seen above.
            -Adding this fixes the weird permanent sunset at the edges of their model
    */
    float theta = acos(sqrt((hemisphereRadius - length2)));

    /*
        Now that we have (R, theta, phi) we have finally constructed the vectors we need to sample
        the sky using a hemisphere. However, during rendering we will want these same vectors to be
        represented using cartesian coordinates. 
        
        If you remember we had originally defined a cartesian system where we built the
        circle with +X to the right of the screen (parallel to the screen width) and +Y going
        upwards (parallel to the screen height). So, since the base was aligned with the XY
        plane the height of the hemisphere must be aligned somehow with the +Z coordinate.
        We'll be transforming our height in spherical to z in cartesian like so:
        
        Height = Z component
        Height = R * cos(theta)
        Z = R * cos(theta)
        (Radius = 1.0)
    [1] Z = cos(theta)

        X and Y can be obtained by realizing that the remaining length of the vector is R*sin(theta).
        This remaining length is the projection of the vector on the XY plane. From then on we can
        reason about how to obtain transformations for X and Y by thinking about how phi behaves when
        it's full length lies either only  on X or only on Y.  This will allows us to break down
        that projection even further into its individual contribution on each axis.

        For X:
        Cartesian: (1, 0, 0) (X, Y ,Z)
        Spherical: (1, 90deg, 0deg) (R, theta, phi)
        X = sin(theta) * ?(phi) (? = some function)
        (Substituting for X, theta, phi)
            1 = sin(90deg) * ?(0)
            1 = 1 * ?(0)
            ? = cos
            (Since cos(0) = 1)
    [2] X = sin(theta) * cos(phi)

        For Y:
        Cartesian: (0, 1, 0) (X, Y ,Z)
        Spherical: (1, 90deg, 90deg) (R, theta, phi)
        Y = sin(theta) * ?(phi) (? = some function)
        (Substituting for Y, theta, phi)
            1 = sin(90deg) * ?(90deg)
            1 = 1 * ?(90deg)
            ? = sin
            (Since sin(90deg) = 1)
    [3] Y = sin(theta) * sin(phi)

    Notice how these equations hold true for both cases:
        cos(phi)  when (phi = 90) is 0
        cos(phi)  when (phi =  0) is 1
        sin(phi)  when (phi = 90) is 1
        sin(phi)  when (phi =  0) is 0
    
    Putting it all together gives us our vector hemisphere surface in cartesian:
    */
    vec3 hemisphereSurface = vec3(sin(theta) * cos(phi),
                                  sin(theta) * sin(phi),
                                  cos(theta));
        
    /*
        We've now got practically everything we need to start raytracing our sky dome properly
        but we've got one more thing left to do before that. If I copy  the 4th condition we
        had laid out earlier:
            4) The camera will point towards y and encompass the whole visible sky

        We see that we have already achieved what we set to do with the second part of the sentence
        "encompass the whole visible sky" by building our hemisphere. Yet although the concept of 
        "pointing towards y" might not be well defined we can see that the hemisphere we have built does 
        not actually "point towards y" since most of the vectors we've created actually point around
        and towards +Z. The reason we want to point towards +Y is arbritary, we could've easily
        looked in some other direction, but since we're basing this on the scratchapixel tutorial
        we'll follow in its steps.

        Yet, if you look at the source code you'll notice that there is no matrix
        transformation done to get the hemisphere to point towards Z.
        Instead you'll notice their equation is a bit different:
            vec3 rayDirection = vec3(sin(theta) * cos(phi),
                                     cos(theta),
                                     sin(theta) * sin(phi));

        If you're like me you're probably thinking wait, that's illegal! They just switch y
        and Z and called it a day! This confused the living hell out of me since it sneakily 
        seems like a bug at first glance. Yet, after going down a rabbithole on why this works
        I can see now that something subtle was actually going on there.

        I started by wanting to write a rotation matrix that would perform the equivalent switch
        of Y and Z but would do so "properly". This led me to s wonder about what was the
        handedness of our coordinate system. Yet, as far as I can tell, it is ambiguous at this
        moment. Throughout our hemisphere construction we have not performed any operation
        that would lock us into a specific handedness. So all of the math we did up to now would
        result in the same vector components in both left or right handed coordinate systems.
        We've said the hemisphere cap lies in the +Z direction, but what does +Z actually mean
        for us is still not set in stone.

        All we know for sure is that the hemisphere base is in the XY plane, +X points to the
        right, parallel to the screen width, +Y points, up parallel to the height and +Z is 
        where the hemisphere cap resides. Yet, it is ambiguous if it points into or out of
        the screen - only that it is perpendicular to the XY plane.

        In the process of reasoning about this I have found a consistent way to determine if
        your coordinate system is left handed or right handed, you probably already knew about 
        this but it's here for me to never forget it:
            1) Realize that handedness determines the result of cross products
            2) I want my cross products to behave as I expect, which means right handed for me 
            3) In a right handed system ixj = +k, jxk = +i, kxi= +j 
                   i
                  / \
                 /   \
                k-----j
            4) Use the way your fingers naturally curl inwards to curl them from i towards j
            5) The thumb now points in the direction of the cross product k (z in our case)
            
        I thought that working out the rotation matrices for left handed and right handed 
        coordinate systems would finally clarify this but I had no luck at all. They are the 
        same!

        I'll give an example below with the actual rotation that we want to do to get +Z
        pointing to our current +Y. Except that instead of rotating by -90deg we'll keep
        it general and think of a rotation with a general angle alpha.
        
        Disclaimer: Angle between Z and Z' should be the same as Y and Y' but your font might 
        make it look different, this is the angle we refer to as alpha.
        
        Right handed system
                     Y 
               Y'    ^  
                \    |   
                 \   |   
                  \  |   
                   \ | 
       Z <-----------0
                    /
                   /
                  /
                 /
                Z'

                                   x         y'          z' 
        RotXRightHanded(alpha) = | 1         0           0     |
                                 | 0   cos(alpha)  -sin(alpha) |
                                 | 0   sin(alpha)   cos(alpha) |

        Left handed system
                     Y 
                     ^         Y'
                     |       / 
                     |     / 
                     |   / 
                     | /
                     0-----------> Z
                      \ 
                       \ 
                        \ 
                         \
                          Z'
                                   x         y           z  
        RotXLeftHanded(alpha) =  | 1         0           0     |
                                 | 0   cos(alpha)  -sin(alpha) |
                                 | 0   sin(alpha)   cos(alpha) |

        So with that. I rest my case, I am not sure in what handedness we are in but I don't 
        care anymore. I will figure it out later I guess. Let's now actually rotate the hemisphere
        and see what that gets us:

                                   x         y           z 
        RotXRightHanded(-90) =   | 1         0           0 |
                                 | 0   cos(-90)  -sin(-90) |
                                 | 0   sin(-90)   cos(-90) |

                                   x  y z 
        RotXRightHanded(-90) =   | 1  0 0 |
                                 | 0  0 1 |
                                 | 0 -1 0 |
        
        So if we multiply this with the original hemisphereSurface(X Y Z) we get:
            RotXRightHanded(-90) * hemisphereSurface = (X, -Z, Y)
        As you can see this is nearly the same as what we saw in the scratchapixel code except
        the scratchapixel code does not negate Z. I don't know why. Failing to negate an axis
        is equivalent to performing a change of basis. The code claims they built the hemisphere
        using left handed coordinates so this would be a legitimate way to perform both the rot
        and the handedness change. I have not been able to determine my handedness but looking
        at the vectors seem to indicate I am in a right handed coordinate system.

    */

    const float ang = -M_PI / 2.0;
    const mat3 xRotMinus90 = mat3(vec3(1,     0,         0   ),  //i
                                  vec3(0,  cos(ang), sin(ang)),  //j
                                  vec3(0, -sin(ang), cos(ang))); //k
    vec3 viewDirection_WS = (xRotMinus90) * hemisphereSurface;

    //vec3 ta = rayOrigin + vec3(1.0, 0.0, 0.0);
    //viewDirection_WS = SetCamera(rayOrigin, ta, 0.0 ) * normalize(vec3(uv, 1.0));

    sunDir = normalize((vec3(sin(time), abs(cos(time)), 0.0)));

    /*
        TODO
        jump to the next section here
    */
    col = Render(rayOrigin, viewDirection_WS);

    GAMMA(col);
    fragColor = vec4(col, 1.0);
}
