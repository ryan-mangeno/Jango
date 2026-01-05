#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float3 pos  [[attribute(0)]];
    float2 cord [[attribute(1)]];
};

struct ControlPoint {
    float3 pos;
    float2 cord;
};

struct PatchUniforms {
    float4x4 u_Model;
    float4x4 u_View;
    float4x4 u_ProjectionView;
    float HEIGHT_SCALE;
    float3 _pad;
};

struct SSAOUniforms {
    float4x4 u_projection;
    float4x4 u_ProjectionView;
    float3 u_CamPos;
    float ScreenWidth;
    float ScreenHeight;
    float _pad0;
    float _pad1;
    float _pad2;
    float3 Samples[64];
};

struct FragmentData {
    float4 position [[position]];
    float4 pos;
    float2 texCoord;
};

template <typename T>
T bilinear_mix(T v0, T v1, T v2, T v3, float2 uv)
{
    T a = mix(v0, v1, uv.x);
    T b = mix(v2, v3, uv.x);
    return mix(a, b, uv.y);
}

kernel void tessellation_kernel(device ControlPoint* control_points            [[buffer(0)]],
                                device MTLQuadTessellationFactorsHalf* factors [[buffer(1)]],
                                constant PatchUniforms& u                      [[buffer(2)]],
                                uint patchID                                   [[thread_position_in_grid]])
{
    const float MAX_TESS_LEVEL = 64.0;
    const float MIN_TESS_LEVEL = 4.0;
    const float MAX_CAM_DIST = 1000.0;
    const float MIN_CAM_DIST = 0.0;

    uint baseIndex = patchID * 4;
    float3 v0 = control_points[baseIndex + 0].pos;
    float3 v1 = control_points[baseIndex + 1].pos;
    float3 v2 = control_points[baseIndex + 2].pos;
    float3 v3 = control_points[baseIndex + 3].pos;

    float4 p1 = u.u_View * u.u_Model * float4(v0, 1.0);
    float4 p2 = u.u_View * u.u_Model * float4(v1, 1.0);
    float4 p3 = u.u_View * u.u_Model * float4(v2, 1.0);
    float4 p4 = u.u_View * u.u_Model * float4(v3, 1.0);

    float dist01 = clamp((abs(p1.z) - MIN_CAM_DIST) / (MAX_CAM_DIST - MIN_CAM_DIST), 0.0, 1.0);
    float dist02 = clamp((abs(p2.z) - MIN_CAM_DIST) / (MAX_CAM_DIST - MIN_CAM_DIST), 0.0, 1.0);
    float dist03 = clamp((abs(p3.z) - MIN_CAM_DIST) / (MAX_CAM_DIST - MIN_CAM_DIST), 0.0, 1.0);
    float dist04 = clamp((abs(p4.z) - MIN_CAM_DIST) / (MAX_CAM_DIST - MIN_CAM_DIST), 0.0, 1.0);

    half TessValue01 = half(mix(MAX_TESS_LEVEL, MIN_TESS_LEVEL, min(dist01, dist03)));
    half TessValue02 = half(mix(MAX_TESS_LEVEL, MIN_TESS_LEVEL, min(dist01, dist02)));
    half TessValue03 = half(mix(MAX_TESS_LEVEL, MIN_TESS_LEVEL, min(dist02, dist04)));
    half TessValue04 = half(mix(MAX_TESS_LEVEL, MIN_TESS_LEVEL, min(dist04, dist03)));

    factors[patchID].edgeTessellationFactor[0] = TessValue01;
    factors[patchID].edgeTessellationFactor[1] = TessValue02;
    factors[patchID].edgeTessellationFactor[2] = TessValue03;
    factors[patchID].edgeTessellationFactor[3] = TessValue04;

    factors[patchID].insideTessellationFactor[0] = max(TessValue02, TessValue04);
    factors[patchID].insideTessellationFactor[1] = max(TessValue01, TessValue03);
}

[[patch(quad, 4)]]
vertex FragmentData tessellation_vertex(device ControlPoint* control_points [[buffer(0)]],
                                        constant PatchUniforms& u           [[buffer(1)]],
                                        texture2d<float> u_HeightMap        [[texture(0)]],
                                        sampler s                           [[sampler(0)]],
                                        float2 position_in_patch            [[position_in_patch]],
                                        uint patchID                        [[patch_id]])
{
    FragmentData out;
    uint baseIndex = patchID * 4;

    float3 p0 = control_points[baseIndex + 0].pos;
    float3 p1 = control_points[baseIndex + 1].pos;
    float3 p2 = control_points[baseIndex + 2].pos;
    float3 p3 = control_points[baseIndex + 3].pos;

    float2 uv0 = control_points[baseIndex + 0].cord;
    float2 uv1 = control_points[baseIndex + 1].cord;
    float2 uv2 = control_points[baseIndex + 2].cord;
    float2 uv3 = control_points[baseIndex + 3].cord;

    float3 oldPosLocal = bilinear_mix(p0, p1, p2, p3, position_in_patch);
    float4 oldPos = u.u_Model * float4(oldPosLocal, 1.0);
    
    float2 texCoord = bilinear_mix(uv0, uv1, uv2, uv3, position_in_patch);
    
    float Height = u_HeightMap.sample(s, texCoord, level(0)).r * u.HEIGHT_SCALE;
    float4 newPos = u.u_Model * float4(0, Height, 0, 0);

    out.pos = oldPos + newPos;
    out.texCoord = texCoord;
    out.position = u.u_ProjectionView * out.pos;

    return out;
}

float3 CalculateNormal(texture2d<float> heightMap, sampler s, float heightScale, float2 texCoord, float2 texelSize)
{
    float left  = heightMap.sample(s, texCoord + float2(-texelSize.x, 0.0)).r * heightScale * 2.0 - heightScale;
    float right = heightMap.sample(s, texCoord + float2( texelSize.x, 0.0)).r * heightScale * 2.0 - heightScale;
    float up    = heightMap.sample(s, texCoord + float2(0.0,  texelSize.y)).r * heightScale * 2.0 - heightScale;
    float down  = heightMap.sample(s, texCoord + float2(0.0, -texelSize.y)).r * heightScale * 2.0 - heightScale;

    return normalize(float3(down - up, 2.0, left - right));
}

fragment float4 fragment_main(FragmentData in              [[stage_in]],
                              constant SSAOUniforms& u     [[buffer(1)]],
                              constant PatchUniforms& pu   [[buffer(2)]],
                              texture2d<float> GPosition   [[texture(0)]],
                              texture2d<float> noisetex    [[texture(1)]],
                              texture2d<float> u_HeightMap [[texture(2)]],
                              sampler s                    [[sampler(0)]])
{
    const float radius = 0.7;
    const float bias = 0.85;
    const float Threshold_dist = 1000.0;

    if (abs(length(u.u_CamPos - in.pos.xyz)) > Threshold_dist)
    {
        return float4(1.0);
    }

    float4 coordinate = u.u_ProjectionView * in.pos;
    coordinate.xyz /= coordinate.w;
    coordinate.xyz = coordinate.xyz * 0.5 + 0.5;

    // Metal coordinates are usually 0-1, but flip Y might be needed depending on pipeline setup.
    // Assuming standard texture mapping here.
    float4 position = GPosition.sample(s, coordinate.xy);

    float2 noiseScale = float2(u.ScreenWidth / 4.0, u.ScreenHeight / 4.0);
    float occlusion = 0.0;
    float3 FragPos = position.xyz;
    
    float3 RandomVec = noisetex.sample(s, coordinate.xy * noiseScale).xyz;
    
    float2 texture_size = float2(u_HeightMap.get_width(), u_HeightMap.get_height());
    float3 normal = CalculateNormal(u_HeightMap, s, pu.HEIGHT_SCALE, in.texCoord, 1.0 / texture_size);

    float3 tangent = normalize(RandomVec - normal * dot(RandomVec, normal));
    float3 bitangent = cross(normal, tangent);
    float3x3 TBN = float3x3(tangent, bitangent, normal);

    for (int i = 0; i < 64; i++)
    {
        float3 samplePos = TBN * u.Samples[i];
        float4 SamplePoint = float4(FragPos + samplePos * radius, 1.0);

        float4 offset = u.u_projection * SamplePoint;
        offset.xyz /= offset.w;
        offset.xyz = offset.xyz * 0.5 + 0.5;

        float3 depth = GPosition.sample(s, offset.xy).rgb;

        float RangeCheck = smoothstep(0.0, 1.0, radius / abs(FragPos.z - depth.z));
        occlusion += (depth.z >= SamplePoint.z + bias ? 1.0 : 0.0) * RangeCheck;
    }

    occlusion = 1.0 - occlusion / 64.0;
    float3 output = float3(pow(occlusion, 4.0));

    return float4(output, 1.0);
}