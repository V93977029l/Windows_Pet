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

vec2 bezier3(vec2 a, vec2 b, vec2 c, vec2 d, float t) {
    float u = 1.0 - t;
    return u*u*u * a + 3.0*u*u*t * b + 3.0*u*t*t * c + t*t*t * d;
}

float sdBezier(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
    float best_t = 0.0;
    float best_d2 = 1e10;

    const int SAMPLES = 12;
    for (int i = 0; i <= SAMPLES; i++) {
        float t = float(i) / float(SAMPLES);
        vec2 q = bezier3(a, b, c, d, t);
        float d2 = dot(q - p, q - p);
        if (d2 < best_d2) { best_d2 = d2; best_t = t; }
    }

    float t = clamp(best_t, 0.0, 1.0);
    for (int i = 0; i < 6; i++) {
        vec2 B = bezier3(a, b, c, d, t);
        float u = 1.0 - t;
        vec2 dB = 3.0*u*u*(b-a) + 6.0*u*t*(c-b) + 3.0*t*t*(d-c);
        vec2 ddB = 6.0*u*(c - 2.0*b + a) + 6.0*t*(d - 2.0*c + b);
        float f = dot(B - p, dB);
        float df = dot(dB, dB) + dot(B - p, ddB);
        if (abs(df) < 1e-9) break;
        t -= f / df;
        t = clamp(t, 0.0, 1.0);
    }
    return length(bezier3(a, b, c, d, t) - p);
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

float halfWidth(float y, vec2 ru_a, vec2 ru_b, vec2 ru_c, vec2 ru_d,
                        vec2 rl_a, vec2 rl_b, vec2 rl_c, vec2 rl_d) {
    if (y <= 0.11) {
        float lo = 0.0, hi = 1.0;
        for (int i = 0; i < 20; i++) {
            float mid = (lo + hi) * 0.5;
            float ym = bezier3(ru_a, ru_b, ru_c, ru_d, mid).y;
            if (ym < y) { lo = mid; } else { hi = mid; }
        }
        return bezier3(ru_a, ru_b, ru_c, ru_d, (lo+hi)*0.5).x;
    } else {
        float lo = 0.0, hi = 1.0;
        for (int i = 0; i < 20; i++) {
            float mid = (lo + hi) * 0.5;
            float ym = bezier3(rl_a, rl_b, rl_c, rl_d, mid).y;
            if (ym < y) { lo = mid; } else { hi = mid; }
        }
        return bezier3(rl_a, rl_b, rl_c, rl_d, (lo+hi)*0.5).x;
    }
}

float sdSlime(vec2 p) {
    float ax = abs(p.x);

    float d_ru = sdBezier(vec2(ax, p.y),
        vec2(0.0, -0.231), vec2(0.25, -0.231), vec2(0.4, -0.055), vec2(0.4, 0.11));

    float d_rl = sdBezier(vec2(ax, p.y),
        vec2(0.4, 0.11), vec2(0.4, 0.22), vec2(0.325, 0.275), vec2(0.25, 0.275));

    float d_bt = sdSegment(vec2(ax, p.y), vec2(0.25, 0.275), vec2(-0.25, 0.275));

    float d = min(min(d_ru, d_rl), d_bt);

    bool inside = p.y > -0.232 && p.y < 0.276 && ax <= halfWidth(p.y,
        vec2(0.0, -0.231), vec2(0.25, -0.231), vec2(0.4, -0.055), vec2(0.4, 0.11),
        vec2(0.4, 0.11), vec2(0.4, 0.22), vec2(0.325, 0.275), vec2(0.25, 0.275));

    return inside ? -d : d;
}
