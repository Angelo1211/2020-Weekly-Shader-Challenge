void 
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    vec2 nuv = ((fragPos) - 0.5*iResolution.xy)/iResolution.y;
    vec2 uv = ((fragPos) / iResolution.xy)  - 0.5;




    vec3 col = vec3(uv, 0.0);

    fragColor = vec4(col, 1.0);
}