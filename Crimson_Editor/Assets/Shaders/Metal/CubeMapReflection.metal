#include <metal_stdlib>
using namespace metal;

constant float PI = 3.14159265359;

struct VertexInput {
    float4 pos [[attribute(0)]];
    float4 dir [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]];
    float3 direction;
};

vertex VertexOutput vertex_main(VertexInput in [[stage_in]])
{
    VertexOutput out;
    out.position = in.pos;
    out.direction = in.dir.xyz / in.dir.w;
    return out;
}

float3 GetIrradiance(float3 direction, texturecube<float> env, sampler s)
{
    float3 normal = normalize(-direction);
    float3 irradiance = float3(0.0);
    
    float3 up = float3(0.0, 1.0, 0.0);
    float3 right = normalize(cross(up, normal));
    up = normalize(cross(normal, right));
    
    float sampleDelta = 0.025;
    float nrSamples = 0.0; 
    
    for(float phi = 0.0; phi < 2.0 * PI; phi += sampleDelta)
    {
        for(float theta = 0.0; theta < 0.5 * PI; theta += sampleDelta)
        {
            float3 tangentSample = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
            float3 sampleVec = tangentSample.x * right + tangentSample.y * up + tangentSample.z * normal; 
            
            irradiance += env.sample(s, sampleVec).rgb * cos(theta) * sin(theta);
            nrSamples++;
        }
    }
    irradiance = PI * irradiance * (1.0 / nrSamples);
    return irradiance;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              texturecube<float> env [[texture(0)]],
                              sampler s [[sampler(0)]])
{
    float3 envColor = GetIrradiance(in.direction, env, s);
    
    envColor = envColor / (envColor + float3(1.0));
    envColor = pow(envColor, float3(1.0/2.2)); 
    
    return float4(envColor, 1.0);
}