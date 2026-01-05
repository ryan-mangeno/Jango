#include <metal_stdlib>
using namespace metal;

// -------------------------------------------------------------------------
// STRUCTURES
// -------------------------------------------------------------------------

struct VertexInput {
    float3 pos  [[attribute(0)]];
    float2 cord [[attribute(1)]];
};

struct PatchUniforms {
    float4x4 u_Model;
    float4x4 u_View;
    float4x4 u_Projection;
    float HEIGHT_SCALE;
    // Padding logic: Metal buffers align to 16 bytes for float3/mat4
    float _pad0; 
    float _pad1;
    float _pad2;
};

struct FragmentData {
    float4 position [[position]];
    float4 pos; // View Space Position
};

// -------------------------------------------------------------------------
// KERNEL (Tessellation Control Equivalent)
// -------------------------------------------------------------------------

// Computes tessellation factors based on camera distance
kernel void tessellation_kernel(device float3* control_points                [[buffer(0)]],
                                device MTLQuadTessellationFactorsHalf* factors [[buffer(1)]],
                                constant PatchUniforms& u                      [[buffer(2)]],
                                uint patchID                                   [[thread_position_in_grid]])
{
    // Constants matching GLSL
    const float MAX_TESS_LEVEL = 64.0;
    const float MIN_TESS_LEVEL = 4.0;
    const float MAX_CAM_DIST = 1000.0;
    const float MIN_CAM_DIST = 0.0;

    // Fetch 4 control points for this patch
    uint baseIndex = patchID * 4;
    float3 v0 = control_points[baseIndex + 0];
    float3 v1 = control_points[baseIndex + 1];
    float3 v2 = control_points[baseIndex + 2];
    float3 v3 = control_points[baseIndex + 3];

    // Transform to View Space to calculate Z depth
    float4 p1 = u.u_View * u.u_Model * float4(v0, 1.0);
    float4 p2 = u.u_View * u.u_Model * float4(v1, 1.0);
    float4 p3 = u.u_View * u.u_Model * float4(v2, 1.0);
    float4 p4 = u.u_View * u.u_Model * float4(v3, 1.0);

    // Calculate normalized distance (0.0 to 1.0)
    float dist01 = clamp((abs(p1.z) - MIN_CAM_DIST) / (MAX_CAM_DIST - MIN_CAM_DIST), 0.0, 1.0);
    float dist02 = clamp((abs(p2.z) - MIN_CAM_DIST) / (MAX_CAM_DIST - MIN_CAM_DIST), 0.0, 1.0);
    float dist03 = clamp((abs(p3.z) - MIN_CAM_DIST) / (MAX_CAM_DIST - MIN_CAM_DIST), 0.0, 1.0);
    float dist04 = clamp((abs(p4.z) - MIN_CAM_DIST) / (MAX_CAM_DIST - MIN_CAM_DIST), 0.0, 1.0);

    // Mix tessellation levels
    half TessValue01 = half(mix(MAX_TESS_LEVEL, MIN_TESS_LEVEL, min(dist01, dist03)));
    half TessValue02 = half(mix(MAX_TESS_LEVEL, MIN_TESS_LEVEL, min(dist01, dist02)));
    half TessValue03 = half(mix(MAX_TESS_LEVEL, MIN_TESS_LEVEL, min(dist02, dist04)));
    half TessValue04 = half(mix(MAX_TESS_LEVEL, MIN_TESS_LEVEL, min(dist04, dist03)));

    // Write to Metal Factors Buffer
    // Indices correspond to edge order: [0]=Left, [1]=Bottom, [2]=Right, [3]=Top (check Metal spec vs GLSL)
    // GLSL gl_TessLevelOuter[0..3] mapping depends on the abstract patch layout.
    // Assuming standard quad mapping:
    factors[patchID].edgeTessellationFactor[0] = TessValue01;
    factors[patchID].edgeTessellationFactor[1] = TessValue02;
    factors[patchID].edgeTessellationFactor[2] = TessValue03;
    factors[patchID].edgeTessellationFactor[3] = TessValue04;

    factors[patchID].insideTessellationFactor[0] = max(TessValue02, TessValue04);
    factors[patchID].insideTessellationFactor[1] = max(TessValue01, TessValue03);
}

// -------------------------------------------------------------------------
// VERTEX (Tessellation Evaluation Equivalent)
// -------------------------------------------------------------------------

// Helper for Bilinear Interpolation
template <typename T>
T bilinear_mix(T v0, T v1, T v2, T v3, float2 uv)
{
    T a = mix(v0, v1, uv.x);
    T b = mix(v2, v3, uv.x);
    return mix(a, b, uv.y);
}

[[patch(quad, 4)]]
vertex FragmentData tessellation_vertex(
    device VertexInput* control_points [[buffer(0)]],
    constant PatchUniforms& u          [[buffer(1)]],
    texture2d<float> u_HeightMap       [[texture(0)]],
    sampler s                          [[sampler(0)]],
    float2 position_in_patch           [[position_in_patch]],
    uint patchID                       [[patch_id]])
{
    FragmentData out;

    // Fetch control points
    uint baseIndex = patchID * 4;
    float3 p0 = control_points[baseIndex + 0].pos;
    float3 p1 = control_points[baseIndex + 1].pos;
    float3 p2 = control_points[baseIndex + 2].pos;
    float3 p3 = control_points[baseIndex + 3].pos;

    float2 uv0 = control_points[baseIndex + 0].cord;
    float2 uv1 = control_points[baseIndex + 1].cord;
    float2 uv2 = control_points[baseIndex + 2].cord;
    float2 uv3 = control_points[baseIndex + 3].cord;

    // Interpolate inputs
    // Note: GLSL quad input order usually goes CCW: 0(BL), 1(BR), 2(TR), 3(TL) or similar
    // Metal patch parameters assume standard bilinear mapping
    // We strictly follow the GLSL logic: Interpolate(gl_in[0]...[3])
    float3 interpolatedPos = bilinear_mix(p0, p1, p2, p3, position_in_patch);
    float2 texCoord = bilinear_mix(uv0, uv1, uv2, uv3, position_in_patch);

    // Height Displacement
    float Height = u_HeightMap.sample(s, texCoord, level(0)).r * u.HEIGHT_SCALE;
    
    // Transform logic matching GLSL:
    // oldPos = View * Model * interpolatedPos
    float4 oldPos = u.u_View * u.u_Model * float4(interpolatedPos, 1.0);
    
    // newPos = View * Model * (0, Height, 0, 0)
    // Note: This applies rotation/scale to the displacement vector
    float4 newPos = u.u_View * u.u_Model * float4(0, Height, 0, 0);

    // Final Position
    out.pos = oldPos + newPos;
    out.position = u.u_Projection * out.pos;

    return out;
}

// -------------------------------------------------------------------------
// FRAGMENT
// -------------------------------------------------------------------------

fragment float4 fragment_main(FragmentData in [[stage_in]])
{
    return in.pos;
}