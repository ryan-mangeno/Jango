#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float3 pos [[attribute(0)]];
    float4 col [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]];
};

struct VertexUniforms {
    float4x4 m_ProjectionView;
    float4x4 m_ModelTransform;
};

struct FragmentUniforms {
    float4 m_color;
};

vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                                constant VertexUniforms& u [[buffer(1)]])
{
    VertexOutput out;
    out.position = u.m_ProjectionView * u.m_ModelTransform * float4(in.pos, 1.0);
    return out;
}

fragment float4 fragment_main(constant FragmentUniforms& u [[buffer(1)]])
{
    return u.m_color;
}