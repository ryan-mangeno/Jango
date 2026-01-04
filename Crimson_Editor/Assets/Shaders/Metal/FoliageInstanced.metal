#include <metal_stdlib>
using namespace metal;

// CONSTANTS & STRUCTURES
#define PI 3.14159265359f
#define MAX_MIP_LEVEL 28.0f

struct VertexInput {
    float4 pos       [[attribute(0)]];
    float2 cord      [[attribute(1)]];
    float3 Normal    [[attribute(2)]];
    float3 Tangent   [[attribute(3)]];
    float3 BiTangent [[attribute(4)]];
    // 'instance_mm' is handled via a buffer in Metal (Buffer 2)
};

struct VertexOutput {
    float4 position [[position]]; // Clip-space position
    float2 tcord;
    float3 objSpacePos;
    float4 m_pos;       // View Space Pos
    float4 m_curPos;    // Current Clip Space
    float4 m_oldPos;    // Old Clip Space
    float3 m_Normal;
    float3 m_Tangent;
    float3 m_BiTangent;
    float3 m_VertexColor;
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
    float4x4 u_View;
    float4x4 u_Projection;
    float4x4 u_Model;
    
    float3 u_cameraPos;
    float  u_Time;
    
    float4 m_color;
    
    float3 u_BoundsExtent;
    int    applyGradientMask;
    
    int    enableWind;
    
    // PBR Props
    float Roughness;
    float Metallic;
};

// -------------------------------------------------------------------------
// HELPER FUNCTIONS
// -------------------------------------------------------------------------

float hash(float2 val)
{
    return fract(1.0e4 * sin(17.0 * val.x + 0.1 * val.y) * (0.1 + abs(sin(13.0 * val.y + val.x))));
}

float hash3D(float3 val)
{
    return hash(float2(hash(val.xy), val.z));
}

// Hashed alpha testing (Ported from NVIDIA GDC 2017)
float HashedAlphaThreshold(float3 objSpacePos, float g_HashedScale)
{
    float maxDeriv = max(length(dfdx(objSpacePos)), length(dfdy(objSpacePos)));
    float pixScale = 1.0 / (g_HashedScale * maxDeriv);

    float2 pixScales = float2(exp2(floor(log2(pixScale))), exp2(ceil(log2(pixScale))));

    float2 alpha = float2(hash3D(floor(pixScales.x * objSpacePos)), 
                          hash3D(floor(pixScales.y * objSpacePos)));

    float lerpFactor = fract(log2(pixScale));

    float x = (1.0 - lerpFactor) * alpha.x + lerpFactor * alpha.y;

    float a = min(lerpFactor, 1.0 - lerpFactor);
    
    float3 cases = float3(x * x / (2.0 * a * (1.0 - a)), 
                          (x - 0.5 * a) / (1.0 - a), 
                          1.0 - ((1.0 - x) * (1.0 - x) / (2.0 * a * (1.0 - a))));
    
    float alpha_f = (x < (1.0 - a)) ? 
                    ((x < a) ? cases.x : cases.y) : 
                    cases.z;

    alpha_f = clamp(alpha_f, 1.0e-6, 1.0);

    return alpha_f;
}

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
    
    // In Metal, Y is usually flipped compared to GL
    // Assuming standard GL-like coords here as per input
    return (cur - old).xy;
}

// -------------------------------------------------------------------------
// VERTEX SHADER
// -------------------------------------------------------------------------
vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                                constant Uniforms& u [[buffer(1)]],
                                // Instancing: Buffer 2 holds array of matrices
                                constant float4x4* instance_mm [[buffer(2)]],
                                uint instanceID [[instance_id]],
                                texture2d<float> Noise [[texture(0)]],
                                sampler sam [[sampler(0)]])
{
    VertexOutput out;
    
    float amplitude = 2.0;
    float wsAmplitude = 0.3;

    // Get Instance Matrix
    float4x4 mat_instance = instance_mm[instanceID];
    
    float4x4 wsGrass = u.u_Model * mat_instance;
    float4 wsVertexPos = wsGrass * in.pos;
    out.objSpacePos = in.pos.xyz;

    float3 origin = float3(wsGrass[3][0], wsGrass[3][1], wsGrass[3][2]);
    
    // Wind System
    float factor = in.pos.y / u.u_BoundsExtent.y;

    if(factor < 0.05) factor = 0;
    
    float2 size = float2(Noise.get_width(), Noise.get_height());
    float2 coord = fmod(origin.xz, size); // mod -> fmod
    coord /= size;

    if(u.enableWind == 1)
    {
        float noiseVal = Noise.sample(sam, coord).r;
        
        float rotVal = (cos(u.u_Time * PI * noiseVal) * cos(u.u_Time * 0.2 * PI)) * wsAmplitude;
        float ws_rotVal = (cos(u.u_Time * PI * 0.8) * cos(u.u_Time * 0.2 * PI)) * wsAmplitude + sin(PI * u.u_Time * noiseVal) * 1.0;
        
        wsVertexPos.x += ws_rotVal * factor;
        wsVertexPos.z += rotVal * factor;
    }

    float4 clip_space = u.u_ProjectionView * wsVertexPos;
    out.m_curPos = clip_space;
    out.m_oldPos = u.u_oldProjectionView * wsVertexPos;
    out.position = clip_space;

    if(u.applyGradientMask == 1)
        out.m_VertexColor = clamp(factor, 0.2, 1.0) * u.m_color.xyz;
    else
        out.m_VertexColor = u.m_color.xyz;
        
    out.tcord = in.cord;
    
    // Normal Matrix calculation (View Space)
    float3x3 viewModelMat = float3x3((u.u_View * wsGrass)[0].xyz, 
                                     (u.u_View * wsGrass)[1].xyz, 
                                     (u.u_View * wsGrass)[2].xyz);

    out.m_Normal    = normalize(viewModelMat * in.Normal);
    out.m_Tangent   = normalize(viewModelMat * in.Tangent);
    out.m_BiTangent = normalize(viewModelMat * in.BiTangent);

    out.m_pos = u.u_View * wsVertexPos;

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
    const float g_HashedScale = 1.0;

    float4 albedo = u_Albedo.sample(sam, in.tcord);
    float alpha_val = albedo.a;
    
    // Hashed Alpha Testing
    if(alpha_val < HashedAlphaThreshold(in.objSpacePos, g_HashedScale))
        discard_fragment();

    // Normal Mapping
    float3 normal = u_NormalMap.sample(sam, in.tcord).rgb;
    normal = normal * 2.0 - 1.0;
    
    float3x3 TBN = float3x3(in.m_Tangent, in.m_BiTangent, in.m_Normal);
    float3 finalNormal;
    
    if (normal.z >= 0.99 && normal.x == 0.0) // Check for default
        finalNormal = normalize(in.m_Normal);
    else
        finalNormal = normalize(TBN * normal);

    // Outputs
    out.gNormal = float4(finalNormal, 1.0);
    out.gVelocity = float4(CalculateVelocity(in.m_curPos, in.m_oldPos), 0.0, 1.0);
    out.gColor = float4(GammaCorrection(albedo.rgb * in.m_VertexColor), 1.0);
    
    // Roughness/Metallic Packing
    // R: Opacity (Unused here directly), G: Roughness, B: AO
    float4 roughMap = u_Roughness.sample(sam, in.tcord);
    out.gRoughnessMetallic = float4(roughMap.r * u.Roughness, u.Metallic, 1.0, 1.0);

    return out;
}