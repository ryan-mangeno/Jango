#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float4 pos   [[attribute(0)]];
    float4 tcord [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 tex_coord;
};

vertex VertexOutput vertex_main(VertexInput in [[stage_in]])
{
    VertexOutput out;
    out.position = in.pos;
    out.tex_coord = in.tcord.xy;
    return out;
}

// finds the fragment with the closest depth in the 3x3 neighborhood
// this is used for velocity dilation to ensure edges move with the foreground object
float2 ClosestFragment(texture2d<float> depthBuffer, sampler s, float2 uv)
{
    float2 pixelDist = 1.0 / float2(depthBuffer.get_width(), depthBuffer.get_height());
    
    // offsets for 3x3 neighborhood excluding center which is handled by minDepth init
    float2 offsets[8] = {
        float2(-pixelDist.x, 0.0),
        float2( pixelDist.x, 0.0),
        float2(0.0,  pixelDist.y),
        float2(0.0, -pixelDist.y),
        float2( pixelDist.x,  pixelDist.y),
        float2(-pixelDist.x, -pixelDist.y),
        float2( pixelDist.x, -pixelDist.y),
        float2(-pixelDist.x,  pixelDist.y)
    };

    float minDepth = depthBuffer.sample(s, uv).r;
    float2 closestCoord = uv;

    for (int i = 0; i < 8; i++)
    {
        float2 sampleCoord = uv + offsets[i];
        float d = depthBuffer.sample(s, sampleCoord).r;
        
        if (d < minDepth)
        {
            minDepth = d;
            closestCoord = sampleCoord;
        }
    }
    return closestCoord;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              texture2d<float> History_Buffer [[texture(0)]],
                              texture2d<float> Current_Buffer [[texture(1)]],
                              texture2d<float> gVelocity      [[texture(2)]],
                              texture2d<float> Depth_Buffer   [[texture(3)]],
                              sampler s                       [[sampler(0)]])
{
    float2 pixelDist = 1.0 / float2(Current_Buffer.get_width(), Current_Buffer.get_height());
    
    float3 current_image = Current_Buffer.sample(s, in.tex_coord).rgb;
    
    float3 leftColor   = Current_Buffer.sample(s, in.tex_coord + float2(-pixelDist.x, 0.0)).rgb;
    float3 rightColor  = Current_Buffer.sample(s, in.tex_coord + float2( pixelDist.x, 0.0)).rgb;
    float3 topColor    = Current_Buffer.sample(s, in.tex_coord + float2(0.0,  pixelDist.y)).rgb;
    float3 bottomColor = Current_Buffer.sample(s, in.tex_coord + float2(0.0, -pixelDist.y)).rgb;

    // neighborhood clamping bounds calculation
    float3 min_color = min(current_image, min(leftColor, min(rightColor, min(topColor, bottomColor))));
    float3 max_color = max(current_image, max(leftColor, max(rightColor, max(topColor, bottomColor))));

    // velocity dilation
    float2 closestFragCoord = ClosestFragment(Depth_Buffer, s, in.tex_coord);
    float2 velocity = gVelocity.sample(s, closestFragCoord).xy;
    
    float2 prevPixel = in.tex_coord - velocity;

    float3 old_image = History_Buffer.sample(s, prevPixel).rgb;
    
    // clamp history to current neighborhood to reduce ghosting
    old_image = clamp(old_image, min_color, max_color);
    
    float mixfactor = 0.9;
    float3 result = mix(current_image, old_image, mixfactor);
    
    return float4(result, 1.0);
}