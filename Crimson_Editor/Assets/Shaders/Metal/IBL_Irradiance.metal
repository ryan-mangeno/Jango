#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float3 position [[attribute(0)]];
};

struct VertexOutput {
    float4 clipPosition [[position]];
    float3 localPosition;
};

struct UniformData {
    float4x4 projectionView;
};

vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                                constant UniformData& uniforms [[buffer(1)]]) 
{
    VertexOutput out;
    out.localPosition = in.position;
    out.clipPosition = uniforms.projectionView * float4(in.position, 1.0);
    return out;
}

constant float PI = 3.14159265359;

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              texturecube<float> environmentMap [[texture(0)]])
{
    constexpr sampler textureSampler(filter::linear, mip_filter::linear);

    float3 normal = normalize(in.localPosition);
    float3 up = float3(0.0, 1.0, 0.0);
    float3 right = normalize(cross(up, normal));
    up = normalize(cross(normal, right));

    float3 irradiance = float3(0.0);
    float sampleDelta = 0.025;
    float nrSamples = 0.0;

    for(float phi = 0.0; phi < 2.0 * PI; phi += sampleDelta)
    {
        for(float theta = 0.0; theta < 0.5 * PI; theta += sampleDelta)
        {
            float3 tangentSample = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
            float3 sampleVec = tangentSample.x * right + tangentSample.y * up + tangentSample.z * normal;

            irradiance += environmentMap.sample(textureSampler, sampleVec, level(0)).rgb * cos(theta) * sin(theta);
            
            nrSamples++;
        }
    }

    irradiance = PI * irradiance * (1.0 / nrSamples);
    
    return float4(irradiance, 1.0);
}