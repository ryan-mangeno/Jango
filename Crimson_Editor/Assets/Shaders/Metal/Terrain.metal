#include <metal_stdlib>
using namespace metal;

struct ControlPoint {
    float3 pos;
    float2 cord;
};

struct PatchUniforms {
    float4x4 u_Model;
    float4x4 u_View;
    float4x4 u_ProjectionView;
    float4x4 u_oldProjectionView; // For velocity buffer
    float3 camPos;
    float HEIGHT_SCALE;
};

struct FragmentUniforms {
    float u_Tiling;
    int numMaskMaps;
    int numTextureMaps;
    float4x4 u_View; // Needed for Normal transformation in frag
};

struct FragmentData {
    float4 position [[position]];
    float2 TexCoord;
    float4 m_curPos;
    float4 m_oldPos;
};

struct GBufferOutput {
    float4 gNormal            [[color(0)]];
    float4 gVelocity          [[color(1)]];
    float4 gColor             [[color(2)]];
    float4 gRoughnessMetallic [[color(3)]];
};

// -------------------------------------------------------------------------
// COMPUTE KERNEL (Tessellation Control)
// -------------------------------------------------------------------------
kernel void tessellation_kernel(device ControlPoint* control_points            [[buffer(0)]],
                                device MTLQuadTessellationFactorsHalf* factors [[buffer(1)]],
                                constant PatchUniforms& u                      [[buffer(2)]],
                                uint patchID                                   [[thread_position_in_grid]])
{
    const float MAX_TESS_LEVEL = 32.0;
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

    // Calculate normalized distance (0.0 to 1.0)
    // Note: p.z/p.w check for perspective division
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

// -------------------------------------------------------------------------
// VERTEX (Tessellation Evaluation & Geometry Logic)
// -------------------------------------------------------------------------
template <typename T>
T bilinear_mix(T v0, T v1, T v2, T v3, float2 uv)
{
    T a = mix(v0, v1, uv.x);
    T b = mix(v2, v3, uv.x);
    return mix(a, b, uv.y);
}

[Image of Displacement Mapping]

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

    float3 interpolatedPos = bilinear_mix(p0, p1, p2, p3, position_in_patch);
    float2 texCoord = bilinear_mix(uv0, uv1, uv2, uv3, position_in_patch);
    out.TexCoord = texCoord;

    // Height Displacement
    float Height = u_HeightMap.sample(s, texCoord, level(0)).r * u.HEIGHT_SCALE;
    
    // Calculate final World Position (Object Space + Displacement -> World Space)
    // Original logic `Interpolate(gl_Position)` implies input was already World Space 
    // if u_Model was applied in TCS. Metal TCS didn't transform control points, so we apply u_Model here
    float4 worldPosBase = u.u_Model * float4(interpolatedPos, 1.0);
    float4 displacement = u.u_Model * float4(0, Height, 0, 0); 
    float4 finalWorldPos = worldPosBase + displacement;

    // Current Clip Position
    out.position = u.u_ProjectionView * finalWorldPos;
    out.m_curPos = out.position;

    // Previous Clip Position (Velocity)
    // Assuming u_oldProjectionView includes old View * old Projection
    out.m_oldPos = u.u_oldProjectionView * finalWorldPos;

    return out;
}

// -------------------------------------------------------------------------
// FRAGMENT
// -------------------------------------------------------------------------
float3 CalculateNormal(texture2d<float> heightMap, sampler s, float heightScale, float2 texCoord, float2 texelSize)
{
    float left  = heightMap.sample(s, texCoord + float2(-texelSize.x, 0.0)).r * heightScale * 2.0 - heightScale;
    float right = heightMap.sample(s, texCoord + float2( texelSize.x, 0.0)).r * heightScale * 2.0 - heightScale;
    float up    = heightMap.sample(s, texCoord + float2(0.0,  texelSize.y)).r * heightScale * 2.0 - heightScale;
    float down  = heightMap.sample(s, texCoord + float2(0.0, -texelSize.y)).r * heightScale * 2.0 - heightScale;

    return normalize(float3(left - right, 2.0, down - up));
}

float3x3 TBN(float3 N)
{   
    float3 T = cross(float3(1.0, 0.0, 0.0), N); 
    float3 B = cross(T, N);
    return float3x3(T, B, N);
}

float2 CalculateVelocity(float4 curPos, float4 oldPos)
{
    float3 cur = curPos.xyz / curPos.w;
    cur.xy = (cur.xy + 1.0) * 0.5;
    
    float3 old = oldPos.xyz / oldPos.w;
    old.xy = (old.xy + 1.0) * 0.5;

    // Metal coordinates y-flip check might be needed depending on engine setup
    // Assuming standard GL-style NDC for now matching glsl logic
    return (cur.xy - old.xy);
}

[Image of Texture Splatting]

fragment GBufferOutput fragment_main(FragmentData in                       [[stage_in]],
                                     constant FragmentUniforms& u            [[buffer(0)]],
                                     constant PatchUniforms& pu              [[buffer(1)]],
                                     texture2d<float> u_HeightMap            [[texture(0)]],
                                     texture2d_array<float> u_Albedo         [[texture(1)]],
                                     texture2d_array<float> u_Roughness      [[texture(2)]],
                                     texture2d_array<float> u_Normal         [[texture(3)]],
                                     texture2d_array<float> u_Masks          [[texture(4)]],
                                     sampler s                               [[sampler(0)]])
{
    GBufferOutput out;

    // Initialize with Base Layer (Index 0)
    float3 uv_tiled = float3(in.TexCoord * u.u_Tiling, 0.0);
    
    float3 total_albedo    = u_Albedo.sample(s, uv_tiled.xy, 0).rgb;
    float3 total_normal    = u_Normal.sample(s, uv_tiled.xy, 0).rgb * 2.0 - 1.0;
    float3 total_roughness = u_Roughness.sample(s, uv_tiled.xy, 0).rgb;

    // Texture Splatting (Mask-based Blending)
    // Metal loops are unrolled by default where static, but we use dynamic range here
    for (int i = 0; i < u.numMaskMaps; i++)
    {
        // Sample next layer
        float3 albedo    = u_Albedo.sample(s, uv_tiled.xy, i + 1).rgb;
        float3 normal    = u_Normal.sample(s, uv_tiled.xy, i + 1).rgb * 2.0 - 1.0;
        float3 roughness = u_Roughness.sample(s, uv_tiled.xy, i + 1).rgb;
        
        // Sample mask
        float weight = u_Masks.sample(s, in.TexCoord, i).r;
        
        total_albedo    = mix(total_albedo, albedo, weight);
        total_normal    = mix(total_normal, normal, weight);
        total_roughness = mix(total_roughness, roughness, weight);
    }

    // Slope-based Procedural Blending
    float2 texelSize = float2(1.0) / float2(u_HeightMap.get_width(), u_HeightMap.get_height());
    float3 geoNormal = CalculateNormal(u_HeightMap, s, pu.HEIGHT_SCALE, in.TexCoord, texelSize);
    
    float slope = 1.0 - geoNormal.y;
    slope = clamp((slope - 0.5) * 10.0 + 0.5, 0.0, 1.0);
    
    // Apply slope procedural layers (remaining textures)
    for (int i = u.numMaskMaps; i < u.numTextureMaps - 1; i++)
    {
        float3 albedo    = u_Albedo.sample(s, uv_tiled.xy, i + 1).rgb;
        float3 normal    = u_Normal.sample(s, uv_tiled.xy, i + 1).rgb * 2.0 - 1.0;
        float3 roughness = u_Roughness.sample(s, uv_tiled.xy, i + 1).rgb;

        total_albedo    = mix(total_albedo, albedo, slope);
        total_normal    = mix(total_normal, normal, slope);
        total_roughness = mix(total_roughness, roughness, slope);
    }

    // Transform Normal to View Space
    float3x3 tbn = TBN(geoNormal);
    float3 finalNormal = float3x3(u.u_View[0].xyz, u.u_View[1].xyz, u.u_View[2].xyz) * tbn * total_normal;
    finalNormal = normalize(finalNormal);

    // Output GBuffer
    out.gNormal            = float4(finalNormal, 1.0);
    out.gVelocity          = float4(CalculateVelocity(in.m_curPos, in.m_oldPos), 0.0, 1.0);
    out.gColor             = float4(pow(total_albedo, 2.2), 1.0); // Gamma Correction
    out.gRoughnessMetallic = float4(total_roughness.r, 0.0, 0.0, 1.0);

    return out;
}