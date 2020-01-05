/*
    Sunday Shader: 1/52 "The second after Midnight"
    New years resolution:make a shader every week & upload them on Sunday.
    Yeah this one is pretty simple but you gotta start somewhere.
    Suggestions, feedback & help is always welcome :D

*/

#define INV_GAMMA 0.454545
#define AA 4
#define M_PI 3.1415926535

#define CLOCKFACE_ID 1.0f
#define CLOCKFACE_RADIUS 0.35f

#define BOX_ID 2.0f
#define BOX_SIZE vec2(0.0025, 0.17)

#define ONETOZERO(num) (num + 1.0f) / 2.0f
#define DEBUGCOL vec3(1.0, 0.0,1.0)

/*Game Plan:
    Todo

    In progress

    Done
    - [x] Draw clock face
    - [x] Mark the 12 hours 
    - [x] Background
    - [x] Clock hands
    - [x] Moving the clock hands

    Maybe next time
    [ ] Draw Roman Numerals
    [ ] Fireworks from behind the clock
    [ ] Buildings w/ lights
    [ ] Hand strikes twelve
*/

float
sdCircle(vec2 pos, float radius)
{
    return length(pos) - radius;
}

float
sdBox(vec2 pos, vec2 sizes)
{
    return length(max(abs(pos) - sizes, vec2(0.0)));
}

float
Map(vec2 uv) 
{
    float res = -1.0;

    vec2 trans = vec2(0.0, -0.12);
    vec2 bigHand = uv - vec2(0.0, 0.12) - trans;
    float a = M_PI* (-iTime / 60.0);
    mat2 rot = mat2(cos(a), sin(a), -sin(a), cos(a));
    bigHand = bigHand * (rot) + trans  ;

    trans = vec2(0.0, -0.09);
    vec2 littleHand = uv - vec2(0.0, 0.09) - trans;
    a = M_PI* (-iTime / (60.0 * 60.0));
    rot = mat2(cos(a), sin(a), -sin(a), cos(a));
    littleHand = littleHand * (rot) + trans;

    //If you're inside the sdf, return it's ID
    res = (sdCircle(uv - vec2(0.0, 0.0), CLOCKFACE_RADIUS) <= 0.0) ? CLOCKFACE_ID : res;  
    res = (sdBox(bigHand, BOX_SIZE) <= 0.0) ? BOX_ID : res;  
    res = (sdBox(littleHand, vec2(0.0025, 0.12)) <= 0.0) ? BOX_ID : res;  
    res = (sdCircle(uv - vec2(0.0, 0.0), 0.01) <= 0.0) ? 3.0f : res;  

    return res;
}

vec3
Shading(vec2 uv, float id)
{
    float r = length(uv);
    float a = atan(uv.y, uv.x);

    vec3 col;
    //Default case
    if (id  == -1.0f)
    {
        bool inRadius = r > 0.36 && r < 0.37;
        bool inAngle = true;
        bool inCircle = inRadius && inAngle;

        if (inCircle)
        {
            col = vec3(0.831, 0.686, 0.216);
        }
        else 
        {
            col = vec3(0.5)* (uv.y + 0.3);
            col = pow(col, vec3(2.0));
        }

    }

    if (id == BOX_ID)
    {
        col = vec3(0.0, 0.0, 0.0);
    }

    if (id == CLOCKFACE_ID)
    {
        col = vec3(1.0, 0.95, 0.85);


        //Tick markers
        {
            bool inRadius = r > 0.26 && r < 0.325;
            if (cos(a * 12.0) > 0.97 && inRadius)
            {
                col = vec3(0.0);
            }
        }

    }

    return col;
}

vec3
Render(vec2 uv)
{
    //Geometry
    float id = Map(uv);

    //Shading
    vec3 col = Shading(uv,id);

    return col;
}

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    vec3 tot;

    //Supersampling AA
#if AA > 1
    for(int i = 0; i < AA; ++i)
    for(int j = 0; j < AA; ++j)
    {
        vec2 offset = vec2(i, j) / float(AA) - 0.5;
        vec2 uv = ((fragPos + offset) - 0.5*iResolution.xy) / iResolution.y;
#else
        vec2 uv = ((fragPos) - 0.5*iResolution.xy) / iResolution.y;
#endif

        //Rendering
        vec3 col = Render(uv);

        //Gamma correction
        col = pow(col, vec3(INV_GAMMA));
        tot += col;
#if AA > 1
    }
    tot /= float(AA*AA);
#endif
    fragColor = vec4(tot, 1.0);
}