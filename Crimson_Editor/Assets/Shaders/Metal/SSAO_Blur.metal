#include <metal_stdlib>
using namespace metal;

// -------------------------------------------------------------------------
// STRUCTS
// -------------------------------------------------------------------------
struct VertexInput {
    float4 position [[attribute(0)]];
    float4 cord     [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 tcord;
};

// -------------------------------------------------------------------------
// VERTEX SHADER
// -------------------------------------------------------------------------
vertex VertexOutput vertex_main(VertexInput in [[stage_in]])
{
    VertexOutput out;
    
    // Pass through position directly (assuming Full Screen Quad in Clip Space -1 to 1)
    out.position = in.position;
    out.tcord = in.cord.xy;
    
    return out;
}

// -------------------------------------------------------------------------
// FRAGMENT SHADER
// -------------------------------------------------------------------------
fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              texture2d<float> SSAOtex [[texture(0)]],
                              sampler sam [[sampler(0)]])
{
    // Calculate texel size (1.0 / width)
    float2 tex_size = float2(SSAOtex.get_width(), SSAOtex.get_height());
    float2 pixel_dimension = 1.0 / tex_size;
    
    float value = 0.0;

    // 5x5 Box Blur
    for(int i = -2; i <= 2; i++)
    {
        for(int j = -2; j <= 2; j++)
        {
            float2 offset = float2(float(i), float(j)) * pixel_dimension;
            value += SSAOtex.sample(sam, in.tcord + offset).r;
        }
    }
    
    // Average the result (25 samples)
    float result = value / 25.0;
    
    return float4(float3(result), 1.0);
}