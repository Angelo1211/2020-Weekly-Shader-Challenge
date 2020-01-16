
float
sdbox(vec2 p , vec2 r)
{
    //vec2 = abs(p) - r;
    vec2 q;
    q.x = abs(p.x) - r.x;
    q.y = abs(p.y) - r.y;

    #if 1
    return length(max(q, 0.0)) + min(max(q.x, q.y),0.0);
    #else
    //MAX
    float newQofX = max(q.x, 0.0);
    float newQofY = max(q.y, 0.0);
    q.x = newQofX;
    q.y = newQofY;

    //LENGTH
    return pow(q.x*q.x
             + q.y*q.y, 0.5);
    #endif
}

void
mainImage(out vec4 fragColor, in vec2 fragPos)
{
    vec2 p = ((fragPos) - 0.5*iResolution.xy)/ iResolution.y;
    vec3 col = vec3(p, 0.0);

    vec2 squareRadius = vec2(0.1, 0.2);

    if (sdbox(p, squareRadius) <= 0.0)
    {
        col = vec3(0.0, 0.0, 1.0);
    }
    col = pow(col, vec3(0.454545));
    fragColor = vec4(col, 1.0);
}