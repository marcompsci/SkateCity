#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex types (deck-specific, distinct from TruckPBR.metal's VertexOut)

struct DeckVertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float2 uv       [[attribute(2)]];
};

struct DeckVertexOut {
    float4 position      [[position]];
    float3 worldNormal;
    float3 worldPosition;
    float2 uv;
    float2 uv2;   // Secondary UV channel for baked lightmap
};

// MARK: - Deck vertex shader
// Projects geometry into clip space and forwards world-space normals + two UV sets.

vertex DeckVertexOut deckVertexShader(
    DeckVertexIn      in          [[stage_in]],
    constant float4x4& mvpMatrix  [[buffer(1)]],
    constant float4x4& modelMatrix [[buffer(2)]])
{
    DeckVertexOut out;
    out.position      = mvpMatrix   * float4(in.position, 1.0);
    out.worldNormal   = (modelMatrix * float4(in.normal, 0.0)).xyz;
    out.worldPosition = (modelMatrix * float4(in.position, 1.0)).xyz;
    out.uv  = in.uv;
    // uv2 uses the same set here; swap to a dedicated baked UV atlas in production
    out.uv2 = in.uv;
    return out;
}

// MARK: - Lightmapped PBR fragment shader
// Multiplies the base albedo by a baked lightmap read on the secondary UV channel.
// The baked lightmap encodes static indirect lighting — essentially free on GPU
// since it collapses all static light bounces into a single texture lookup.

fragment float4 deckLightmapFragmentShader(
    DeckVertexOut       in               [[stage_in]],
    texture2d<float>    baseTexture      [[texture(0)]],
    texture2d<float>    lightmapTexture  [[texture(1)]],
    constant float&     ambientIntensity [[buffer(0)]])
{
    constexpr sampler s(filter::linear, mip_filter::linear, address::repeat);

    float4 baseColor     = baseTexture.sample(s, in.uv);
    float4 lightmapColor = lightmapTexture.sample(s, in.uv2);

    // Multiply-blend: static light bake modulates the albedo.
    // The lighting is practically free on GPU — no dynamic shadow rays needed.
    float3 litSurface = baseColor.rgb * lightmapColor.rgb * ambientIntensity;

    return float4(litSurface, baseColor.a);
}
