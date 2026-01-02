#include <metal_stdlib>
using namespace metal;

// STRUCTS
struct VertexIn {
    float4 pos [[attribute(0)]];
    float4 dir [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]]; // Clip-space position
    float3 direction;             // Interpolated view direction
};

// VERTEX SHADER
vertex VertexOut vertex_main(VertexIn in [[stage_in]])
{
    VertexOut out;
    
    // view direction 
    out.direction = -in.dir.xyz;
    
    out.position = in.pos;
    
    return out;
}

// FRAGMENT SHADER 
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texturecube<float> env [[texture(0)]], // Cube Map Texture
                              sampler envSampler [[sampler(0)]])     // Sampler State
{
    // Sample Environment Map
    float3 envColor = env.sample(envSampler, normalize(in.direction)).rgb;

    // Gamma Correction (Linearize)
    envColor = pow(envColor, float3(2.2));

    // Exposure Tone Mapping
    float3 mapped = float3(1.0) - exp(-envColor * 1.0);

    // Clamp
    mapped = clamp(mapped, 0.0, 1.0);

    return float4(mapped, 1.0);
}