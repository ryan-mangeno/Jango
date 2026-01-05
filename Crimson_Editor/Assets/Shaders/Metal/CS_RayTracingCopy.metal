#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float4 pos [[attribute(0)]];
    float4 coord [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 tcoord;
};

vertex VertexOutput vertex_main(VertexInput in [[stage_in]])
{
    VertexOutput out;
    out.position = in.pos;
    out.tcoord = in.coord.xy;
    return out;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              texture2d<float> InputTexture [[texture(0)]],
                              sampler s [[sampler(0)]])
{
    return float4(InputTexture.sample(s, in.tcoord).rgb, 1.0);
}