//Practice 0: 28/04/20 (18m)
//Practice 1: 29/04/20 (18m)
//Practice 2: 30/04/20 (23m)
//Practice 3: 02/05/20
//Practice 4: 03/05/20

#iChannel0 "./textures/MediumNoise.png"
#iChannel0::WrapMode "Repeat"

vec3 
dNoise2D(vec2 uv)
{
    ivec2 id = ivec2(floor(uv));
    vec2 fr = fract(uv);

    //Cubic interpolation
    vec2 interp = fr*fr*(3.0-2.0*fr);
    vec2 dInterp = 6.0*fr*(1.0-fr);

    //bottom
    float bl = texelFetch(iChannel0, id + ivec2(0, 0)&255, 0).x; //a
    float br = texelFetch(iChannel0, id + ivec2(1, 0)&255, 0).x; //b
    float b = mix(bl, br, interp.x);

    //Top
    float tl = texelFetch(iChannel0, id + ivec2(0, 1)&255, 0).x; //c
    float tr = texelFetch(iChannel0, id + ivec2(1, 1)&255, 0).x; //d
    float t = mix(tl, tr, interp.x);

    //bilinear filtering
    float noise = mix(b, t, interp.y);

    //check mathematica doc
    vec2 derivatives = dInterp*(vec2(br - bl, tl-bl) + (bl - br - tl + tr) *interp.yx);
    return vec3(noise, derivatives);
}

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 temp, i, j, k;

    temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    k = normalize(target - eye);
    i = normalize(cross(temp, k));
    j = cross(k , i);

    return mat3(i, j , k);
}

const mat2 m2 = mat2(0.8,-0.6,0.6,0.8);

float
terrainM(vec3 x)
{
    float SC = 250.0;
	vec2  p = x.xz*0.003/SC;
    float a = 0.0;
    float b = 1.0;
	vec2  d = vec2(0.0);
    for( int i=0; i<9; i++ )
    {
        vec3 n = dNoise2D(p);
        d += n.yz;
        a += b*n.x/(1.0+dot(d,d));
		b *= 0.5;
        p = m2*p*2.0;
    }
    return x.y - a;
}

#define MAX_DIST 2000.0
#define MAX_STEPS 200
#define MIN_DIST 0.001
float
intersect(vec3 ro, vec3 rd)
{
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        float h = terrainM(ro + t*rd);

        if(abs(h) < t* MIN_DIST) break;

        t +=h;
    }

    return t;
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col;

    float t = intersect(ro, rd);

    col += t;

    return col;
}


#define INV_GAMMA 0.454545
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    //camera
    vec2 uv = ((fragCoord) - 0.5*iResolution.xy)/ iResolution.y;
    float nearp = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0, 2.0, 0.0);
    vec3 ro = ta + vec3(0.0, 0.0, -10.0);
    mat3 cam = SetCamera(ro, ta , roll);
    vec3 rd = cam * normalize(vec3(uv, nearp));

    vec3 col = Render(ro, rd);
    //col = vec3(texelFetch(iChannel0, ivec2(fragCoord)&255, 0).x);
    //col = vec3(dNoise2D(uv*20.0));


    //col = pow(col, vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}