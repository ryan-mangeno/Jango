#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float4 aPos      [[attribute(0)]];
    float4 aTexCoord [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 v_texCoord;
};

struct Uniforms {
    float exposure;
    float BloomAmount;
};

// ACES tone mapping curve (approximation)
float3 ACESFilm(float3 x)
{
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;

    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

vertex VertexOutput vertex_main(VertexInput in [[stage_in]])
{
    VertexOutput out;
    out.position = in.aPos;
    out.v_texCoord = in.aTexCoord.xy;
    return out;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              constant Uniforms& u       [[buffer(1)]],
                              texture2d<float> inputImage    [[texture(0)]], // Bloom Texture
                              texture2d<float> OriginalImage [[texture(1)]], // Scene Texture
                              sampler s [[sampler(0)]])
{
    // Sample HDR (bloom) and original scene color
    float3 hdrColor = inputImage.sample(s, in.v_texCoord).rgb;
    float3 originalColor = OriginalImage.sample(s, in.v_texCoord).rgb;

    // Simple Reinhard tone mapping on bloom
    // Note: This matches your GLSL logic exactly
    hdrColor *= u.exposure / (1.0 + hdrColor / u.exposure);

    // Add bloom to original scene
    // This uses the bloom color itself as the mixing weight, creating a quadratic blending effect
    float3 targetColor = originalColor + hdrColor * u.BloomAmount;
    originalColor = mix(originalColor, targetColor, hdrColor);

    // Apply filmic tone mapping
    originalColor = ACESFilm(originalColor);
    
    // Gamma correction
    originalColor = pow(originalColor, float3(1.0 / 2.2));

    return float4(originalColor, 1.0);
}