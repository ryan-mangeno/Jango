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
    float FilterRadius;
    float3 ImageRes;
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
    float x = (1.0 / u.ImageRes.x) * u.FilterRadius;
    float y = (1.0 / u.ImageRes.y) * u.FilterRadius;

    float4 a = inputImage.sample(s, float2(in.tcord.x - x, in.tcord.y + y));
    float4 b = inputImage.sample(s, float2(in.tcord.x,     in.tcord.y + y));
    float4 c = inputImage.sample(s, float2(in.tcord.x + x, in.tcord.y + y));

    float4 d = inputImage.sample(s, float2(in.tcord.x - x, in.tcord.y));
    float4 e = inputImage.sample(s, float2(in.tcord.x,     in.tcord.y));
    float4 f = inputImage.sample(s, float2(in.tcord.x + x, in.tcord.y));

    float4 g = inputImage.sample(s, float2(in.tcord.x - x, in.tcord.y - y));
    float4 h = inputImage.sample(s, float2(in.tcord.x,     in.tcord.y - y));
    float4 i = inputImage.sample(s, float2(in.tcord.x + x, in.tcord.y - y));

    float4 calculated_color = e * 4.0;
    calculated_color += (b + d + f + h) * 2.0;
    calculated_color += (a + c + g + i) * 1.0;
    calculated_color *= 1.0 / 16.0;

    return float4(calculated_color.xyz, 1.0);
}