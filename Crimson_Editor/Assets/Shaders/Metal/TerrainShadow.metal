#include <metal_stdlib>
using namespace metal;

#define MAX_TESS_LEVEL 64.0
#define MIN_TESS_LEVEL 4.0
#define MAX_CAM_DIST 1000.0
#define MIN_CAM_DIST 0.0

struct VertexInput {
    float3 pos  [[attribute(0)]];
    float2 cord [[attribute(1)]];
};

struct ControlPointData {
    float4 positionWS; 
    float2 TexCoord;
};

struct VertexOut {
    float4 position [[position]];
    ControlPointData data;
};

struct TerrainUniforms {
    float4x4 u_Model;
    float4x4 u_View;
    float4x4 u_ProjectionView;
    float4x4 LightProjection; 
    float HEIGHT_SCALE;
};

vertex VertexOut vertex_main(VertexInput in [[stage_in]])
{
    VertexOut out;
    out.data.positionWS = float4(in.pos, 1.0); 
    out.data.TexCoord = in.cord;
    out.position = float4(in.pos, 1.0); 
    return out;
}

kernel void tessellation_kernel(constant VertexOut* controlPoints         [[buffer(0)]],
                                device MTLQuadTessellationFactorsHalf* factors [[buffer(1)]],
                                constant TerrainUniforms& u               [[buffer(2)]],
                                uint patchID                              [[thread_position_in_grid]])
{
    uint i0 = patchID * 4 + 0;
    uint i1 = patchID * 4 + 1;
    uint i2 = patchID * 4 + 2;
    uint i3 = patchID * 4 + 3;

    float4 p1 = u.u_View * u.u_Model * controlPoints[i0].data.positionWS;
    float4 p2 = u.u_View * u.u_Model * controlPoints[i1].data.positionWS;
    float4 p3 = u.u_View * u.u_Model * controlPoints[i2].data.positionWS;
    float4 p4 = u.u_View * u.u_Model * controlPoints[i3].data.positionWS;

    float dist01 = clamp((abs(p1.z) - MIN_CAM_DIST) / (MAX_CAM_DIST - MIN_CAM_DIST), 0.0, 1.0);
    float dist02 = clamp((abs(p2.z) - MIN_CAM_DIST) / (MAX_CAM_DIST - MIN_CAM_DIST), 0.0, 1.0);
    float dist03 = clamp((abs(p3.z) - MIN_CAM_DIST) / (MAX_CAM_DIST - MIN_CAM_DIST), 0.0, 1.0);
    float dist04 = clamp((abs(p4.z) - MIN_CAM_DIST) / (MAX_CAM_DIST - MIN_CAM_DIST), 0.0, 1.0);

    float TessValue01 = mix(MAX_TESS_LEVEL, MIN_TESS_LEVEL, min(dist01, dist03));
    float TessValue02 = mix(MAX_TESS_LEVEL, MIN_TESS_LEVEL, min(dist01, dist02));
    float TessValue03 = mix(MAX_TESS_LEVEL, MIN_TESS_LEVEL, min(dist02, dist04));
    float TessValue04 = mix(MAX_TESS_LEVEL, MIN_TESS_LEVEL, min(dist04, dist03));

    factors[patchID].edgeTessellationFactor[0] = (half)TessValue01;
    factors[patchID].edgeTessellationFactor[1] = (half)TessValue02;
    factors[patchID].edgeTessellationFactor[2] = (half)TessValue03;
    factors[patchID].edgeTessellationFactor[3] = (half)TessValue04;

    factors[patchID].insideTessellationFactor[0] = (half)max(TessValue02, TessValue04);
    factors[patchID].insideTessellationFactor[1] = (half)max(TessValue01, TessValue03);
}

float4 InterpolateVec4(float4 v0, float4 v1, float4 v2, float4 v3, float2 t)
{
    float4 a = mix(v0, v1, t.x);
    float4 b = mix(v2, v3, t.x);
    return mix(a, b, t.y);
}

float2 InterpolateVec2(float2 v0, float2 v1, float2 v2, float2 v3, float2 t)
{
    float2 a = mix(v0, v1, t.x);
    float2 b = mix(v2, v3, t.x);
    return mix(a, b, t.y);
}

struct TessEvalOutput {
    float4 position [[position]];
};

// We use the raw VertexOut buffer directly instead of patch_control_point<T>
// This bypasses the template error completely
[[patch(quad, 4)]]
vertex TessEvalOutput tessellation_evaluation_main(
    constant VertexOut* controlPoints           [[buffer(0)]],
    constant TerrainUniforms& u                 [[buffer(1)]],
    texture2d<float> u_HeightMap                [[texture(0)]],
    sampler sam                                 [[sampler(0)]],
    float2 patch_coord                          [[position_in_patch]],
    uint patchID                                [[patch_id]]) // We need patchID to index manually
{
    TessEvalOutput out;

    // Manually index the control points for this patch
    uint i0 = patchID * 4 + 0;
    uint i1 = patchID * 4 + 1;
    uint i2 = patchID * 4 + 2;
    uint i3 = patchID * 4 + 3;

    float4 oldPos = InterpolateVec4(controlPoints[i0].data.positionWS, 
                                    controlPoints[i1].data.positionWS, 
                                    controlPoints[i2].data.positionWS, 
                                    controlPoints[i3].data.positionWS, 
                                    patch_coord);
    
    float2 texCoord = InterpolateVec2(controlPoints[i0].data.TexCoord, 
                                      controlPoints[i1].data.TexCoord, 
                                      controlPoints[i2].data.TexCoord, 
                                      controlPoints[i3].data.TexCoord, 
                                      patch_coord);

    float Height = u_HeightMap.sample(sam, texCoord).r * u.HEIGHT_SCALE;
    
    float4 displacedPos = oldPos + float4(0, Height, 0, 0);

    out.position = u.LightProjection * u.u_Model * displacedPos;

    return out;
}

fragment void fragment_main()
{
}