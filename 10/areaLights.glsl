#iChannel0 "file://./textures/MediumNoise256.png"
#iChannel0::WrapMode "Repeat"

#iChannel1 "file://./textures/MetallicSurface.jpg"
#iChannel1::WrapMode "Repeat"

#include "./common.glsl"

vec3  areaLightPos;
vec3  areaLightCol;
float areaLightRad;

float _time;

#define SPHERE_ID 0.0
#define GROUND_ID 1.0
#define LIGHT_ID 2.0
vec2 
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    //Geometry
    //UOP(sdSphere(p - vec3(0.0, 0.0, 0.1), 0.25), SPHERE_ID);
    UOP(sdGroundPlane(p + 0.25), GROUND_ID);

    //Lights
    float r = 0.2;
    areaLightRad = 0.1;
    areaLightPos = vec3(r * cos(_time), 0.2 * cos(_time) + 0.1, r*sin(_time));
    UOP(sdSphere(p - areaLightPos, areaLightRad), LIGHT_ID);

    return res;
}

#define MAX_DIST 20.0
#define MAX_STEPS 200
#define MIN_DIST 0.001
vec2 
RayMarch(vec3 ro, vec3 rd)
{
    float t = 0.0;
    vec2 res = vec2(-1.0);
    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        vec2 hit = Map(ro + rd*t);

        if(abs(hit.x) < t * MIN_DIST)
        {
            res = vec2(t, hit.y);
            break;
        }

        t += hit.x;
    }
    return res;
}

vec3
CalcNormal(vec3 p)
{
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(Map(p + e.xyy).x - Map(p - e.xyy).x,
                          Map(p + e.yxy).x - Map(p - e.yxy).x,
                          Map(p + e.yyx).x - Map(p - e.yyx).x));
}

float
CalcSoftShadows(vec3 ro, vec3 rd)
{
    float k = 2.0;
    float n = 1.0;
    for(float t = 0.2; t < MAX_DIST;)
    {
        float h = Map(ro + t*rd).x;
        if(h < MIN_DIST) return 0.0;

        n = min(n, h*k/ t);
        t += h;
    }
    return n;
}

float specTrowbridgeReitz( float HoN, float a, float aP )
{
	float a2 = a * a;
	float aP2 = aP * aP;
	return ( a2 * aP2 ) / pow( HoN * HoN * ( a2 - 1.0 ) + 1.0, 2.0 );
}

float visSchlickSmithMod( float NoL, float NoV, float r )
{
	float k = pow( r * 0.5 + 0.5, 2.0 ) * 0.5;
	float l = NoL * ( 1.0 - k ) + k;
	float v = NoV * ( 1.0 - k ) + k;
	return 1.0 / ( 4.0 * l * v );
}

float fresSchlickSmith( float HoV, float f0 )
{
	return f0 + ( 1.0 - f0 ) * pow( 1.0 - HoV, 5.0 );
}

float sphereLight( vec3 pos, vec3 N, vec3 V, vec3 r, float f0, float roughness, float NoV, out float NoL )
{
	vec3 L = areaLightPos - pos;
	vec3 centerToRay = dot( L, r ) * r - L;
	vec3 closestPoint = L + centerToRay * clamp( areaLightRad / length( centerToRay ), 0.0, 1.0 );	
	vec3 l = normalize( closestPoint );
	vec3 h = normalize( V + l );
	
	NoL	= clamp( dot( N, l ), 0.0, 1.0 );
	float HoN = clamp( dot( h, N ), 0.0, 1.0 );
	float HoV = dot( h, V );
	
	float distL = length( L );
	float alpha = roughness * roughness;
	float alphaPrime = clamp( areaLightRad / ( distL * 2.0 ) + alpha, 0.0, 1.0 );
	
	float specD	= specTrowbridgeReitz( HoN, alpha, alphaPrime );
	float specF	= fresSchlickSmith( HoV, f0 );
	float specV	= visSchlickSmithMod( NoL, NoV, roughness );
	
	return specD * specF * specV * NoL;
}

vec3 
Render(vec3 ro, vec3 rd)
{
    //Ray setup
    vec3 col = vec3(0.0);
    vec2 res = RayMarch(ro, rd);
    float t = res.x;
    float id = res.y;

    //Sky rendering
    vec3 sky = vec3(0.0);
    col += sky;

    //Opaque pass
    if(id >= 0.0)
    {
        //Geometry
        vec3 P = ro + t*rd;
        vec3 N = CalcNormal(P);
        vec3 V = -rd;
        vec3 R = reflect(rd, N);
        float NdotV = saturate(dot(N,V));

        //Noise
        float noise =  texture(iChannel0, P.xz* 0.2).x * 0.5 ;
        noise +=  texture(iChannel0, P.xz*0.4).y * 0.25; 
        noise +=  texture(iChannel0, P.xz*0.8).z * 0.125;
        noise +=  texture(iChannel0, P.xz*1.6).z * 0.125 / 2.0;

        //Material & PBR parameters
        col = vec3(1.0);
        if(id == LIGHT_ID) {col = vec3(1.0, 1.0, 1.0);return col;}

        //Albedo
        vec3 albedo = texture(iChannel1, P.xz* 0.4).xyz;
        albedo = mix( albedo, albedo * 1.3, noise * 0.35 - 1.0 ); 

        //Roughness
        float roughness = 0.2 - clamp( 0.5 - dot( albedo, albedo ), 0.05, 0.95 );

        //F0
        float f0 = 0.3;

        //Lighting
        vec3 lin = vec3(0.0);
        vec3 L = normalize(vec3(1.0, 1.0, 0.0));
        float diff = saturate(dot(L, N));

        //Shadowing
        //diff *= CalcSoftShadows(P, L);

        //Shading
        float NdotLSphere;
        float specSph	= sphereLight( P, N, V, R, f0, roughness, NdotV, NdotLSphere );
        lin += albedo * 0.3183 * ( NdotLSphere ) + specSph;

        //lin += 1.00 * diff * vec3(1.0, 1.0, 1.0);
        col *= lin;
    }

    //Fog
    col = mix(col, vec3(0.0), 1.0 - exp(-0.1*t*t));
    return saturate(col);
}

#define AA 2
void 
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    _time = iTime / 2.0;
    vec3 tot = vec3(0.0);

    //Camera
    float nearP = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0);
    vec3 ro = ta + vec3(0.0, 0.2, -1.0);

#if AA > 1
    for(int i =0; i < AA; ++i)
    for(int j =0; j < AA; ++j)
    {
        vec2 offset = 0.5 - vec2(i, j) / float(AA);
        vec2 uv = ((fragPos + offset) - 0.5*iResolution.xy) / iResolution.y;
#else
        vec2 uv = ((fragPos) - 0.5*iResolution.xy) / iResolution.y;
#endif 
        mat3 cam = SetCamera(ro, ta, roll);
        vec3 rd = cam * normalize(vec3(uv, nearP));

        vec3 col = Render(ro, rd);

        tot += col;
#if AA > 1
    }
    tot /= float(AA* AA);
#endif

    GAMMA(tot);
    fragColor = vec4(tot, 1.0);
}