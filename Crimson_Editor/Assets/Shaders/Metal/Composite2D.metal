#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float4 a_Position  [[attribute(0)]];
    float2 a_TexCoord  [[attribute(1)]];
    float4 a_Color     [[attribute(2)]];
    float  a_SlotIndex [[attribute(3)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 TexCoord;
    float4 Color;
    float SlotIndex;
};

struct Uniforms {
    float4x4 u_ProjectionView;
    float4x4 u_ModelTransform;
};

struct FragmentUniforms {
    float4 u_color;
};

vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                                constant Uniforms& u [[buffer(1)]])
{
    VertexOutput out;
    out.Color = in.a_Color;
    out.SlotIndex = in.a_SlotIndex;
    out.TexCoord = in.a_TexCoord;
    
    out.position = u.u_ProjectionView * in.a_Position;
    return out;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              constant FragmentUniforms& u_frag [[buffer(1)]],
                              array<texture2d<float>, 32> textures [[texture(0)]],
                              sampler s [[sampler(0)]])
{
    int index = int(in.SlotIndex);
    
    // clamp index to safety
    // if index is out of bounds metal behavior can be undefined or crash
    if (index < 0 || index >= 32) {
         return in.Color; 
    }

    return textures[index].sample(s, in.TexCoord) * in.Color;
}