
    //Init common vars
    vec3 col = vec3(0.0);

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
