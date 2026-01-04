#include <metal_stdlib>
using namespace metal;

// -------------------------------------------------------------------------
// STRUCTURES
// -------------------------------------------------------------------------

struct VertexInput {
    float4 pos       [[attribute(0)]];
    float2 cord      [[attribute(1)]];
    float3 Normal    [[attribute(2)]];
    float3 Tangent   [[attribute(3)]];
    float3 BiTangent [[attribute(4)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 tcord;
    float4 m_pos;
    float4 m_curPos;
    float4 m_oldPos;
    float3 m_Normal;
    float3 m_Tangent;
    float3 m_BiTangent;
};

struct FragmentOutput {
    float4 gNormal            [[color(0)]];
    float4 gVelocity          [[color(1)]];
    float4 gColor             [[color(2)]];
    float4 gRoughnessMetallic [[color(3)]];
};

struct Uniforms {
    float4x4 u_ProjectionView;
    float4x4 u_oldProjectionView;
    float4x4 u_Model;
    float4x4 u_View;

    float Roughness;
    float Metallic;
    float Transperancy;
    float4 m_color;
};

// -------------------------------------------------------------------------
// HELPER FUNCTIONS
// -------------------------------------------------------------------------

float3 GammaCorrection(float3 color)
{
    return pow(color, float3(2.2));
}

float2 CalculateVelocity(float4 curPos, float4 oldPos)
{
    float4 cur = curPos / curPos.w;
    cur.xy = (cur.xy + 1.0) * 0.5;

    float4 old = oldPos / oldPos.w;
    old.xy = (old.xy + 1.0) * 0.5;

    return (cur - old).xy;
}

// -------------------------------------------------------------------------
// VERTEX SHADER
// -------------------------------------------------------------------------

vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                                constant Uniforms& u [[buffer(1)]])
{
    VertexOutput out;
    
    float4 clip_space = u.u_ProjectionView * u.u_Model * in.pos;
    out.m_curPos = clip_space;
    out.m_oldPos = u.u_oldProjectionView * u.u_Model * in.pos;

    out.position = clip_space;
    out.tcord = in.cord;
    
    // Normal Matrix Construction (View * Model top-left 3x3)
    float3x3 normalMatrix = float3x3((u.u_View * u.u_Model)[0].xyz,
                                     (u.u_View * u.u_Model)[1].xyz,
                                     (u.u_View * u.u_Model)[2].xyz);

    out.m_Normal    = normalize(normalMatrix * in.Normal);
    out.m_Tangent   = normalize(normalMatrix * in.Tangent);
    out.m_BiTangent = normalize(normalMatrix * in.BiTangent);
    
    out.m_pos = u.u_View * u.u_Model * in.pos;

    return out;
}

// -------------------------------------------------------------------------
// FRAGMENT SHADER
// -------------------------------------------------------------------------

fragment FragmentOutput fragment_main(VertexOutput in [[stage_in]],
                                      constant Uniforms& u [[buffer(1)]],
                                      texture2d<float> u_Albedo    [[texture(0)]],
                                      texture2d<float> u_Roughness [[texture(1)]],
                                      texture2d<float> u_NormalMap [[texture(2)]],
                                      sampler sam [[sampler(0)]])
{
    FragmentOutput out;

    float4 albedo = u_Albedo.sample(sam, in.tcord) * u.m_color;

    // Dither Matrix for transparency
    float4x4 thresholdMatrix = float4x4(
        1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
        13.0 / 17.0, 5.0 / 17.0, 15.0 / 17.0, 7.0 / 17.0,
        4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
        16.0 / 17.0, 8.0 / 17.0, 14.0 / 17.0, 6.0 / 17.0
    );

    // Metal pixel coords (in.position.xy) are equivalent to gl_FragCoord.xy
    int x = int(in.position.x);
    int y = int(in.position.y);
    float val = thresholdMatrix[x % 4][y % 4];

    if(albedo.a < val)
        discard_fragment();

    // Normal Mapping
    float3 normal = u_NormalMap.sample(sam, in.tcord).rgb;
    normal = normal * 2.0 - 1.0;
    
    float3x3 TBN = float3x3(in.m_Tangent, in.m_BiTangent, in.m_Normal);
    
    // Check for white texture (default normal)
    if (normal.z >= 0.99 && normal.x == 0.0)
        out.gNormal = float4(in.m_Normal, 1.0);
    else
        out.gNormal = float4(normalize(TBN * normal), 1.0);

    out.gVelocity = float4(CalculateVelocity(in.m_curPos, in.m_oldPos), 0.0, 1.0);
    out.gColor = float4(GammaCorrection(albedo.rgb), 1.0);
    
    float3 roughnessMetallic = u_Roughness.sample(sam, in.tcord).xyz;
    out.gRoughnessMetallic = float4(roughnessMetallic.r * u.Roughness, roughnessMetallic.g * u.Metallic, 1.0, 1.0);

    return out;
}