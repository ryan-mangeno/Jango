#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float4 pos           [[attribute(0)]];
    float2 cord          [[attribute(1)]];
    float3 Normal        [[attribute(2)]]; // Kept for attribute layout compatibility
    float3 Tangent       [[attribute(3)]]; // Kept for attribute layout compatibility
    float3 BiTangent     [[attribute(4)]]; // Kept for attribute layout compatibility
    float  materialindex [[attribute(5)]];
};

struct VertexOutput {
    float4 position [[position]];
    float4 m_pos; // View Space Position
    float2 tcord;
    float  m_materialindex [[flat]];
};

struct Uniforms {
    float4x4 u_ProjectionView;
    float4x4 u_Model;
    float4x4 u_View;
};

struct FragUniforms {
    int isFoliage;
};

vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                                constant Uniforms& u [[buffer(1)]])
{
    VertexOutput out;
    
    // Standard MVP transform for clip space
    out.position = u.u_ProjectionView * u.u_Model * in.pos;
    
    // View space position for SSAO/Depth calculations
    out.m_pos = u.u_View * u.u_Model * in.pos;
    
    out.tcord = in.cord;
    out.m_materialindex = in.materialindex;
    
    return out;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              constant FragUniforms& fu [[buffer(2)]],
                              texture2d_array<float> alpha_texture [[texture(0)]],
                              sampler s [[sampler(0)]])
{
    if (fu.isFoliage == 1)
    {
        int index = int(in.m_materialindex);
        
        // Sample the specific slice of the texture array
        float alpha = alpha_texture.sample(s, in.tcord, index).r;
        
        if (alpha <= 0.06)
        {
            discard_fragment();
        }
    }

    // Output view-space position
    return in.m_pos;
}