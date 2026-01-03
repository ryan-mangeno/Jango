#include <metal_stdlib>
using namespace metal;


struct VertexInput {
    float4 aPos [[attribute(0)]];
    float4 aDir [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]]; // Clip-space position
    float2 texCoord;
    float3 viewDir;
};

// -------------------------------------------------------------------------
// Vertex Shader
// -------------------------------------------------------------------------

vertex VertexOutput vertex_main(VertexInput in [[stage_in]])
{
    VertexOutput out;
    
    // Pass position directly
    out.position = in.aPos;

    // Normalize coordinates from [-1,1] to [0,1]
    out.texCoord = in.aPos.xy * 0.5 + 0.5;

    // Pass direction
    out.viewDir = in.aDir.xyz;

    return out;
}

// -------------------------------------------------------------------------
// Fragment Shader
// -------------------------------------------------------------------------

struct Uniforms {
    float3 sun_direction;
};

// alculates sun highlight contribution
float3 getSun(float sunViewDot)
{
    float sunSize = 0.03;
    return float3(1.0, 0.8, 0.8) * step(1.0 - sunSize * sunSize, sunViewDot);
}

// Calculates final sky color
float3 getSky(float3 viewDir, constant Uniforms& uniforms, texture2d_array<float> skyGradient, sampler sam)
{
    float3 sunDirNorm = normalize(-uniforms.sun_direction);
    float3 viewDirNorm = normalize(viewDir);

    float sunViewDot = dot(sunDirNorm, viewDirNorm);
    float sunZenithDot = sunDirNorm.y;
    float viewZenithDot = viewDirNorm.y;

    float sunZenithDot01 = (sunZenithDot + 1.0) * 0.5;

    // Metal Texture Array Sampling:
    // sample(sampler, float2 coord, uint array_slice)
    
    // Base Sky Color (Slice 0)
    float3 skyColor = skyGradient.sample(sam, float2(sunZenithDot01, 0.5), 0).rgb;

    // View Zenith Gradient (Slice 1)
    float3 viewZenithColor = skyGradient.sample(sam, float2(sunZenithDot01, 0.5), 1).rgb;
    float vzMask = pow(clamp(1.0 - viewZenithDot, 0.0, 1.0), 8.0);

    // Sun View Highlight
    float3 sunViewColor = skyGradient.sample(sam, float2(sunZenithDot01, 0.5), 1).rgb;
    float svMask = pow(clamp(sunViewDot, 0.0, 1.0), 256.0);

    return skyColor + getSun(sunViewDot) + vzMask * viewZenithColor + svMask * sunViewColor;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              constant Uniforms& uniforms [[buffer(0)]],
                              texture2d_array<float> Sky_Gradient [[texture(0)]],
                              sampler skySampler [[sampler(0)]])
{
    float3 color = getSky(in.viewDir, uniforms, Sky_Gradient, skySampler);
    
    return float4(color, 1.0);
}