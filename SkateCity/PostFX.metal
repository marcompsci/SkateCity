#include <metal_stdlib>
using namespace metal;

// MARK: - ACES Filmic Tonemapping + Post-Processing
// Full-screen SCNTechnique pass:
//   – ACES filmic tonemapping (same curve used in Unreal/Lumberyard)
//   – Subtle chromatic aberration at screen edges
//   – Film grain (temporal, seed by time)
//   – Vignette

// MARK: Vertex

struct PostFXVert {
    float4 position [[position]];
    float2 uv;
};

// Full-screen triangle using vertex_id (no VBO needed)
vertex PostFXVert postfx_vert(uint vid [[vertex_id]]) {
    PostFXVert out;
    // Two triangles covering the screen via a 3-vertex trick
    float2 pos = float2((vid & 1) ? 3.0 : -1.0,
                        (vid & 2) ? -3.0 : 1.0);
    out.position = float4(pos, 0.0, 1.0);
    out.uv = float2(pos.x * 0.5 + 0.5, -pos.y * 0.5 + 0.5);
    return out;
}

// MARK: ACES approximation (Krzysztof Narkowicz)
static inline half3 aces(half3 x) {
    const half a = 2.51h, b = 0.03h, c = 2.43h, d = 0.59h, e = 0.14h;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

// MARK: Fragment — uniforms passed from Swift via SCNTechnique
struct PostFXUniforms {
    float time;          // scn_frame.time
    float exposure;      // EV offset: default 0.0
    float vignetteStr;   // 0 = off, 1 = strong
    float grainStr;      // 0 = off, ~0.04 = subtle
    float aberration;    // 0 = off, ~0.004 = subtle
    float nightBlend;    // 0 = day, 1 = night (shifts white balance warm → cool)
};

fragment half4 postfx_frag(PostFXVert    in          [[stage_in]],
                            texture2d<half> colorTex  [[texture(0)]],
                            constant PostFXUniforms& u [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    float2 uv = in.uv;
    float2 center = uv - 0.5;

    // Chromatic aberration — barrel-distorted R/G/B sample offsets
    float ca = u.aberration * (dot(center, center) * 3.0 + 0.3);
    half r = colorTex.sample(s, uv + center * ca * 1.0).r;
    half g = colorTex.sample(s, uv                     ).g;
    half b = colorTex.sample(s, uv - center * ca * 1.0).b;
    half4 col = half4(r, g, b, 1.0);

    // Exposure
    col.rgb *= pow(2.0h, half(u.exposure));

    // Day/Night white balance tint
    // Day: neutral; Night: slight cool blue + lifted blacks for sodium-lamp amber
    half3 dayTint   = half3(1.00, 1.00, 1.00);
    half3 nightTint = half3(0.88, 0.94, 1.06);
    col.rgb *= mix(dayTint, nightTint, half(u.nightBlend));

    // ACES tonemapping
    col.rgb = aces(col.rgb);

    // Gamma (linearise → sRGB)
    col.rgb = pow(col.rgb, half3(1.0h / 2.2h));

    // Subtle lift in the shadows for cinematic look (Uncharted-style toe)
    col.rgb = col.rgb * 1.02h - half3(0.01h);

    // Vignette — smooth radial darkening
    float dist = dot(center, center);
    float vig  = 1.0 - dist * u.vignetteStr * 1.8;
    col.rgb *= half(max(vig, 0.0));

    // Film grain — per-pixel hash seeded by uv + time
    float2 noiseUV = uv * 1024.0 + float2(u.time * 73.13, u.time * 47.7);
    float2 p2 = fract(noiseUV * float2(123.34, 456.21));
    p2 += dot(p2, p2 + 45.32);
    float grain = fract(p2.x * p2.y) - 0.5;
    col.rgb += half3(half(grain * u.grainStr));

    return saturate(col);
}

// MARK: - Bloom Bright-Pass

struct BloomVert {
    float4 position [[position]];
    float2 uv;
};

vertex BloomVert bloom_vert(uint vid [[vertex_id]]) {
    BloomVert out;
    float2 pos = float2((vid & 1) ? 3.0 : -1.0, (vid & 2) ? -3.0 : 1.0);
    out.position = float4(pos, 0.0, 1.0);
    out.uv = float2(pos.x * 0.5 + 0.5, -pos.y * 0.5 + 0.5);
    return out;
}

/// Bright-pass: extract pixels brighter than `threshold` (HDR-aware, pre-tonemap).
fragment half4 bloom_brightpass(BloomVert in [[stage_in]],
                                 texture2d<half> src [[texture(0)]]) {
    constexpr sampler s(filter::linear);
    half4 col = src.sample(s, in.uv);
    half lum  = dot(col.rgb, half3(0.2126h, 0.7152h, 0.0722h));
    half knee = 0.4h;
    half contribution = smoothstep(knee, knee + 0.4h, lum);
    return half4(col.rgb * contribution, 1.0h);
}

/// 9-tap gaussian blur (separable — run twice: horizontal then vertical).
fragment half4 bloom_blur(BloomVert in [[stage_in]],
                           texture2d<half> src [[texture(0)]],
                           constant float2& direction [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    // Gaussian weights (sigma ≈ 2.0)
    const half weights[5] = { 0.227027h, 0.316216h, 0.070270h, 0.316216h, 0.227027h };
    const float offsets[5] = { -2.0, -1.0, 0.0, 1.0, 2.0 };
    half4 result = 0.0h;
    for (int i = 0; i < 5; ++i) {
        result += weights[i] * src.sample(s, in.uv + direction * offsets[i]);
    }
    return result;
}

/// Additive bloom composite: original + blurred bright-pass.
fragment half4 bloom_composite(BloomVert in [[stage_in]],
                                 texture2d<half> original [[texture(0)]],
                                 texture2d<half> bloom    [[texture(1)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    half4 col = original.sample(s, in.uv);
    half4 bl  = bloom.sample(s, in.uv);
    return half4(col.rgb + bl.rgb * 0.55h, col.a);
}
