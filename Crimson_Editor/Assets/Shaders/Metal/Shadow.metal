#include <metal_stdlib>
using namespace metal;

// -------------------------------------------------------------------------
// STRUCTS
// -------------------------------------------------------------------------
struct VertexInput {
    float4 pos       [[attribute(0)]];
    float2 cord      [[attribute(1)]];
    float3 Normal    [[attribute(2)]];
    float3 Tangent   [[attribute(3)]];
    float3 BiTangent [[attribute(4)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 tcord;
};

struct Uniforms {
    float4x4 LightProjection;
    float4x4 u_Model;
    int isFoliage;
};


// -------------------------------------------------------------------------
// VERTEX SHADER
// -------------------------------------------------------------------------
vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                                constant Uniforms& u [[buffer(1)]])
{
    VertexOutput out;
    
    out.tcord = in.cord;
    out.position = u.LightProjection * u.u_Model * in.pos;
    
    return out;
}

// -------------------------------------------------------------------------
// FRAGMENT SHADER
// -------------------------------------------------------------------------
// Returns void because we only care about Depth (written automatically)
fragment void fragment_main(VertexOutput in [[stage_in]],
                            constant Uniforms& u [[buffer(1)]],
                            texture2d<float> u_Alpha [[texture(0)]],
                            sampler sam [[sampler(0)]])
{
    float3 alpha = u_Alpha.sample(sam, in.tcord).rgb;
    
    // Foliage Masking
    if (u.isFoliage == 1 && alpha.r <= 0.06) 
    {
        discard_fragment();
    }
    
    // No return needed; Depth is written automatically if we don't discard
}