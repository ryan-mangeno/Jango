#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float4 pos  [[attribute(0)]];
    float4 cord [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 tcord;
};

struct Uniforms {
    float BightnessThreshold;
};

vertex VertexOutput vertex_main(VertexInput in [[stage_in]])
{
    VertexOutput out;
    out.position = in.pos;
    out.tcord = in.cord.xy;
    return out;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              constant Uniforms& u [[buffer(1)]],
                              texture2d<float> inputImage [[texture(0)]],
                              sampler s [[sampler(0)]])
{
    float4 FragColor = inputImage.sample(s, in.tcord);

    float brightness = dot(FragColor.rgb, float3(0.2126, 0.7152, 0.0722));
    
    if (brightness > u.BightnessThreshold)
    {
        return float4(FragColor.rgb, 1.0);
    }
    else
    {
        return float4(0.0, 0.0, 0.0, 1.0);
    }
}