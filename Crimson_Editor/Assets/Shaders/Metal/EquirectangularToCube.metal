#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float3 position [[attribute(0)]];
};

struct VertexOutput {
    float4 clipPosition [[position]]; // Required for rasterization
    float3 localPosition;             // Passed to fragment
};

struct UniformData {
    float4x4 projectionView;
};

// VERTEX SHADER
vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                               constant UniformData& uniforms [[buffer(1)]]) 
{
    VertexOutput out;
    
    // Pass raw position to fragment (for spherical sampling)
    out.localPosition = in.position;
    
    // Calculate clip space position
    out.clipPosition = uniforms.projectionView * float4(in.position, 1.0);
    
    return out;
}

// Constants
constant float2 invAtan = float2(0.1591, 0.3183);

// Helper function
float2 SampleSphericalMap(float3 v)
{
    // Note: GLSL 'atan(y, x)' is 'atan2(y, x)' in Metal
    float2 uv = float2(atan2(v.z, v.x), asin(v.y));
    uv *= invAtan;
    uv += 0.5;
    return uv;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                             texture2d<float> hdrTexture [[texture(0)]])
{
    // Create a sampler (Linear filtering is standard for HDR maps)
    constexpr sampler textureSampler(filter::linear, address::repeat);

    // Normalize the interpolated position
    float2 uv = SampleSphericalMap(normalize(in.localPosition));

    // Sample the HDR texture
    float3 envColor = hdrTexture.sample(textureSampler, uv).rgb;

    // Tone Mapping (Exposure Correction)
    // "1.0" exposure is hardcoded here, matching GLSL
    float3 mapped = float3(1.0) - exp(-envColor * 1.0);

    return float4(mapped, 1.0);
}