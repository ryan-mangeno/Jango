#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float4 a_Position [[attribute(0)]];
    float4 a_TexCoord [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 TexCoord;
};

struct Uniforms {
    float3 ImageRes; // Typically alignment needs padding to float4, usually safe if last
};

vertex VertexOutput vertex_main(VertexInput in [[stage_in]])
{
    VertexOutput out;
    out.position = in.a_Position;
    out.TexCoord = in.a_TexCoord.xy;
    return out;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              constant Uniforms& u [[buffer(1)]],
                              texture2d<float> inputImage [[texture(0)]],
                              sampler s [[sampler(0)]])
{
    float2 pixelSize = 1.0 / u.ImageRes.xy;
    float x = pixelSize.x;
    float y = pixelSize.y;

    // 13-tap filter
    float4 a = inputImage.sample(s, float2(in.TexCoord.x - 2.0 * x, in.TexCoord.y + 2.0 * y));
    float4 b = inputImage.sample(s, float2(in.TexCoord.x,           in.TexCoord.y + 2.0 * y));
    float4 c = inputImage.sample(s, float2(in.TexCoord.x + 2.0 * x, in.TexCoord.y + 2.0 * y));

    float4 d = inputImage.sample(s, float2(in.TexCoord.x - 2.0 * x, in.TexCoord.y));
    float4 e = inputImage.sample(s, float2(in.TexCoord.x,           in.TexCoord.y));
    float4 f = inputImage.sample(s, float2(in.TexCoord.x + 2.0 * x, in.TexCoord.y));

    float4 g = inputImage.sample(s, float2(in.TexCoord.x - 2.0 * x, in.TexCoord.y - 2.0 * y));
    float4 h = inputImage.sample(s, float2(in.TexCoord.x,           in.TexCoord.y - 2.0 * y));
    float4 i = inputImage.sample(s, float2(in.TexCoord.x + 2.0 * x, in.TexCoord.y - 2.0 * y));

    float4 j = inputImage.sample(s, float2(in.TexCoord.x - x,       in.TexCoord.y + y));
    float4 k = inputImage.sample(s, float2(in.TexCoord.x + x,       in.TexCoord.y + y));
    float4 l = inputImage.sample(s, float2(in.TexCoord.x - x,       in.TexCoord.y - y));
    float4 m = inputImage.sample(s, float2(in.TexCoord.x + x,       in.TexCoord.y - y));

    float4 calculatedColor = e * 0.125;
    calculatedColor += (a + c + g + i) * 0.03125;
    calculatedColor += (b + d + f + h) * 0.0625;
    calculatedColor += (j + k + l + m) * 0.125;

    return float4(calculatedColor.rgb, 1.0);
}