#include <metal_stdlib>
using namespace metal;

constant float DEG2RAD = 0.01745329251f;

struct VertexInput {
    float4 pos           [[attribute(0)]];
    float2 cord          [[attribute(1)]];
    float  materialindex [[attribute(5)]];
};

struct VertexOutput {
    float4 position [[position]];
    float4 m_Pos; 
    float2 tcoord;
    float  m_materialindex [[flat]];
};

struct Uniforms {
    float4x4 u_View;
    float4x4 u_Model;
    float4x4 u_Projection;
    float u_Time;
};

float4x4 CreateScaleMatrix(float scale)
{
    return float4x4(float4(scale, 0, 0, 0),
                    float4(0, scale, 0, 0),
                    float4(0, 0, scale, 0),
                    float4(0, 0, 0, 1));
}

float4x4 CreateRotationMat(float x, float y, float z)
{
    x = x * DEG2RAD;
    y = y * DEG2RAD;
    z = z * DEG2RAD;

    float4x4 aroundX = float4x4(float4(1, 0, 0, 0),
                                float4(0, cos(x), sin(x), 0),
                                float4(0, -sin(x), cos(x), 0),
                                float4(0, 0, 0, 1));

    float4x4 aroundY = float4x4(float4(cos(y), 0, -sin(y), 0),
                                float4(0, 1, 0, 0),
                                float4(sin(y), 0, cos(y), 0),
                                float4(0, 0, 0, 1));

    float4x4 aroundZ = float4x4(float4(cos(z), sin(z), 0, 0),
                                float4(-sin(z), cos(z), 0, 0),
                                float4(0, 0, 1, 0),
                                float4(0, 0, 0, 1));

    return aroundX * aroundY * aroundZ;
}

vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                                constant Uniforms& u [[buffer(1)]],
                                device float4x4* instance_mm [[buffer(2)]],
                                texture2d<float> Noise [[texture(0)]],
                                sampler s [[sampler(0)]],
                                uint instanceID [[instance_id]])
{
    VertexOutput out;
    
    float amplitude = 40.0;
    float wsAmplitude = 0.6;
    
    float4x4 instanceMat = instance_mm[instanceID];
    float4x4 wsGrass = u.u_Model * instanceMat;
    float4 wsVertexPos = wsGrass * in.pos;
    
    float3 origin = float3(wsGrass[3][0], wsGrass[3][1], wsGrass[3][2]);
    float factor = distance(wsVertexPos.xyz, origin) / 10.0;
    if (factor < 0.0) factor = 0.0;

    float3 coord = fmod(abs(wsVertexPos.xyz), 256.0);
    coord /= 256.0;

    // explicit level 0 required for vertex texture fetch
    float3 noise = Noise.sample(s, coord.xz * 2.0, level(0)).rgb * 2.0;
    
    float3 rotVal = float3(sin(u.u_Time + noise.r) * 0.5 + 0.5 + 1.0) * factor * amplitude;
    float3 ws_rotVal = float3(noise.r * sin(u.u_Time) * 0.5 + 0.5) * factor * wsAmplitude;

    float4x4 ws_rot = CreateRotationMat(0, 0, ws_rotVal.y);
    float4x4 rot = CreateRotationMat(0, rotVal.y, 0);

    float val = Noise.sample(s, coord.xz * 10.0, level(0)).r;

    float4x4 transform = ws_rot * wsGrass * rot * CreateScaleMatrix(val * 2.0);
    
    out.position = u.u_Projection * u.u_View * transform * in.pos;
    out.m_Pos = u.u_View * transform * in.pos; // view space position
    out.m_materialindex = in.materialindex;
    out.tcoord = in.cord;
    
    return out;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              texture2d_array<float> u_Alpha [[texture(0)]],
                              sampler s [[sampler(0)]])
{
    int index = int(in.m_materialindex);
    float alpha = u_Alpha.sample(s, in.tcoord, index).rgb.r;

    // alpha test commented out to match input
    // if(alpha <= 0.06) discard_fragment();

    return in.m_Pos;
}