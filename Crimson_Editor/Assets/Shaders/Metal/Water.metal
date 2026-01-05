#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float4 pos [[attribute(0)]];
};

struct VertexOutput {
    float4 position [[position]];
};

struct Uniforms {
    float4x4 u_ProjectionView;
    float4 u_Color;
};

vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                                constant Uniforms& u [[buffer(1)]])
{
    VertexOutput out;
    out.position = u.u_ProjectionView * in.pos;
    return out;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              constant Uniforms& u [[buffer(1)]])
{
    return u.u_Color;
}