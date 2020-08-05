#define INV_GAMMA 0.45454545

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 k = normalize(target - eye);
    vec3 temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    vec3 i = normalize(cross(temp, k));
    vec3 j = cross(k, i);

    return mat3(i, j, k);
}

void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Camera 
    float nearp = 1.0;
    float roll = 0.0;
    vec3 ta = vec3(0.0);
    vec3 ro = ta + vec3(0.0, 0.0, -1.0);
    vec2 uv = ((fragCoord) - 0.5*iResolution.xy) / iResolution.y;
    mat3 cam = SetCamera(ro, ta, roll);
    vec3 rd = cam * normalize(vec3(uv, nearp));

    // Rendering
    vec3 col = vec3(rd);

    //Post processing
    col = pow(col , vec3(INV_GAMMA));
    fragColor = vec4(col, 1.0);
}