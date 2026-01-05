#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float4 pos   [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    float4x4 u_ProjectionView;
};

vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                                constant Uniforms& u [[buffer(1)]])
{
    VertexOutput out;
    out.position = u.u_ProjectionView * in.pos;
    out.color = in.color;
    return out;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]])
{
    return in.color;
}