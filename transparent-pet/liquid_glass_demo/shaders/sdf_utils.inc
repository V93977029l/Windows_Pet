float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

float superellipseCornerSDF(vec2 p, float r, float n) {
    p = abs(p);
    float v = pow(pow(p.x, n) + pow(p.y, n), 1.0 / n);
    return v - r;
}

float roundedRectSDF(vec2 p, vec2 center, float width, float height, float cornerRadius, float n, float dpr) {
    p -= center;
    float cr = cornerRadius * dpr;
    vec2 d = abs(p) - vec2(width * dpr, height * dpr) * 0.5;
    
    float dist;
    if (d.x > -cr && d.y > -cr) {
        vec2 cornerCenter = sign(p) * (vec2(width * dpr, height * dpr) * 0.5 - vec2(cr));
        vec2 cornerP = p - cornerCenter;
        dist = superellipseCornerSDF(cornerP, cr, n);
    } else {
        dist = min(max(d.x, d.y), 0.0) + length(max(d, vec2(0.0)));
    }
    
    return dist;
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float sdSlime(vec2 p) {
    p *= 2.0;
    
    float body = length(p - vec2(0, -0.1)) - 0.5;
    
    float leftBlob = length(p - vec2(-0.35, 0.1)) - 0.28;
    float rightBlob = length(p - vec2(0.35, 0.1)) - 0.28;
    
    float bottom = length(p - vec2(0, 0.4)) - 0.22;
    
    float d = 1.0;
    d = min(d, body);
    d = min(d, leftBlob);
    d = min(d, rightBlob);
    d = min(d, bottom);
    
    float mergeRadius = 0.15;
    
    d = smin(d, leftBlob, mergeRadius);
    d = smin(d, rightBlob, mergeRadius);
    d = smin(d, bottom, mergeRadius * 0.8);
    
    return d;
}