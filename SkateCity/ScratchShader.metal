#include <metal_stdlib>
using namespace metal;

// Pseudo-random value for organic scratch edge noise
float pseudo_noise(float2 co) {
    return fract(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
}

/// Writes wear-and-tear scratch marks into the deck's roughness/scratch map
/// at the UV location of a grind contact point.
kernel void paint_board_scratches(
    texture2d<float, access::read_write> scratchMap  [[texture(0)]],
    const device float2&  collisionUV                [[buffer(0)]],
    const device float&   grindIntensity             [[buffer(1)]],
    uint2 id                                         [[thread_position_in_grid]])
{
    if (id.x >= scratchMap.get_width() || id.y >= scratchMap.get_height()) return;

    float2 currentUV = float2(id) / float2(scratchMap.get_width(), scratchMap.get_height());
    float  dist        = distance(currentUV, collisionUV);
    float  scratchWidth = 0.015 * grindIntensity;

    if (dist < scratchWidth) {
        float4 original      = scratchMap.read(id);
        float  noise         = pseudo_noise(currentUV * 100.0);
        float  scratchAmount = (1.0 - (dist / scratchWidth)) * noise;
        float  newScratch    = clamp(original.r + scratchAmount, 0.0, 1.0);
        scratchMap.write(float4(newScratch, original.g, original.b, 1.0), id);
    }
}
