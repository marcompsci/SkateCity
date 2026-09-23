#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position      [[position]];
    float3 worldNormal;
    float3 worldPosition;
    float2 uv;
};

// GGX/Trowbridge-Reitz normal distribution function
float distributionGGX(float3 N, float3 H, float roughness) {
    float a     = roughness * roughness;
    float a2    = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float denom = (NdotH * NdotH * (a2 - 1.0) + 1.0);
    return a2 / (M_PI_F * denom * denom + 0.000001);
}

/// PBR fragment shader for metallic skateboard trucks.
/// Bound to SCNMaterial via SCNProgram; samples the HDRI environment cube for
/// ambient reflections and evaluates a single directional (sun) specular lobe.
fragment float4 truckMetallicFragmentShader(
    VertexOut        in               [[stage_in]],
    texturecube<float> environmentCube [[texture(0)]],
    constant float3& cameraPosition   [[buffer(0)]],
    constant float3& sunDirection     [[buffer(1)]])
{
    constexpr sampler cubeSampler(filter::linear, mip_filter::linear);

    float3 N = normalize(in.worldNormal);
    float3 V = normalize(cameraPosition - in.worldPosition);
    float3 L = normalize(-sunDirection);
    float3 H = normalize(V + L);

    // Truck material constants (brushed aluminium)
    float3 albedo    = float3(0.75, 0.75, 0.75);
    float  metallic  = 0.95;
    float  roughness = 0.45;

    float3 F0 = mix(float3(0.04), albedo, metallic);
    float  D  = distributionGGX(N, H, roughness);

    float3 directSpecular    = float3(D * 0.25);
    float3 ambientReflection = environmentCube.sample(cubeSampler, reflect(-V, N)).rgb
                             * F0 * (1.0 - roughness);

    return float4((albedo * 0.1) + directSpecular + ambientReflection, 1.0);
}
