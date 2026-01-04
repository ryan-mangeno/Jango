#include <metal_stdlib>
using namespace metal;

#define MAX_LIGHTS 100
#define MAX_MIP_LEVEL 28.0f
#define PI 3.14159265359f

struct VertexInput {
    float4 pos           [[attribute(0)]];
    float2 cord          [[attribute(1)]];
    float3 Normal        [[attribute(2)]];
    float3 Tangent       [[attribute(3)]];
    float3 BiTangent     [[attribute(4)]];
    float  materialindex [[attribute(5)]];
};

struct VertexOutput {
    float4 position [[position]];
    float4 m_pos;
    float2 tcord;
    float3 m_Normal;
    float3 m_Tangent;
    float3 m_BiTangent;
    uint   m_materialindex [[flat]];
};

struct Uniforms {
    float4x4 u_ProjectionView;
    float4x4 u_Model;
    
    // Shadows
    float4x4 MatrixShadow[4];
    float    Ranges[5];
    float4x4 view; 

    float  u_depth;
    float3 EyePosition;
    float4 m_color;

    // Lights
    float3 DirectionalLight_Direction;
    // Arrays in Metal buffers are 16-byte aligned (float4 stride)
    float4 PointLight_Position[MAX_LIGHTS]; 
    float4 PointLight_Color[MAX_LIGHTS];
    int    Num_PointLights;

    // PBR
    float Roughness;
    float Metallic;
};

// --- Helper Functions ---

float NormalDistribution_GGX(float NdotH, float roughness)
{
    float alpha2 = pow(roughness, 4.0);
    float denom = (pow(NdotH, 2.0) * (alpha2 - 1.0) + 1.0);
    return alpha2 / (PI * pow(denom, 2.0));
}

float Geometry_GGX(float dp, float roughness)
{
    float k = pow(roughness + 1.0, 2.0) / 8.0;
    return dp / (dp * (1.0 - k) + k);
}

float3 Fresnel(float VdotH, float metallic, float3 m_color, float roughness)
{
    float3 f0 = (metallic == 0.0) ? float3(0.04) : float3(0.4);
    f0 = mix(f0, m_color, metallic);
    return f0 + (max(float3(1.0 - roughness), f0) - f0) * pow(clamp(1.0 - VdotH, 0.0, 1.0), 5.0);
}

float3 SpecularBRDF(float3 LightDir, float3 ViewDir, float3 Normal, float roughness, float metallic, float3 m_color, thread float &vdoth)
{
    float3 Half = normalize(ViewDir + LightDir);
    float NdotH = max(dot(Normal, Half), 0.0);
    float NdotV = max(dot(Normal, ViewDir), 0.000001);
    float NdotL = max(dot(Normal, LightDir), 0.000001);
    float VdotH = max(dot(ViewDir, Half), 0.0);

    vdoth = VdotH;

    float Dggx = NormalDistribution_GGX(NdotH, roughness);
    float Gggx = Geometry_GGX(NdotV, roughness) * Geometry_GGX(NdotL, roughness);
    float3 fresnel = Fresnel(VdotH, metallic, m_color, roughness);

    float denominator = 4.0 * NdotL * NdotV + 0.0001;
    return (Dggx * Gggx * fresnel) / denominator;
}

float3 ColorCorrection(float3 color)
{
    color = clamp(color, 0.0, 1.0);
    color = pow(color, float3(1.0/2.2)); 
    color = clamp(color, 0.0, 1.0);
    color = float3(1.0) - exp(-color * 2.0);
    color = clamp(color, 0.0, 1.0);
    color = 1.3 * (color - 0.5) + 0.5;
    return color;
}

float CalculateShadow(int level, float4 lightSpacePos, 
                      texture2d<float> sm0, texture2d<float> sm1, 
                      texture2d<float> sm2, texture2d<float> sm3, 
                      sampler sam)
{
    float3 p = lightSpacePos.xyz / lightSpacePos.w;
    p = p * 0.5 + 0.5;
    p.y = 1.0 - p.y; // Metal Y-flip

    float bias = 0.00001;
    float ShadowSum = 0.0;
    
    // Select cascade manually
    texture2d<float> selectedMap;
    if (level == 0) selectedMap = sm0;
    else if (level == 1) selectedMap = sm1;
    else if (level == 2) selectedMap = sm2;
    else selectedMap = sm3;
    
    float2 texelSize = 1.0 / float2(selectedMap.get_width(), selectedMap.get_height());

    for(int i = -1; i <= 1; i++) {
        for(int j = -1; j <= 1; j++) {
            float2 offset = float2(i, j) * texelSize;
            float depth = selectedMap.sample(sam, p.xy + offset).r;
            if(depth + bias > p.z)
                ShadowSum += 1.0;
        }
    }
    return ShadowSum / 9.0;
}

// --- Vertex Shader ---
vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                                constant Uniforms& u [[buffer(1)]])
{
    VertexOutput out;
    out.position = u.u_ProjectionView * u.u_Model * in.pos;
    out.m_pos = u.u_Model * in.pos;
    out.m_materialindex = uint(in.materialindex);
    out.tcord = in.cord;

    float3x3 normalMat = float3x3(u.u_Model[0].xyz, u.u_Model[1].xyz, u.u_Model[2].xyz);
    out.m_Normal = normalize(normalMat * in.Normal);
    out.m_Tangent = normalize(normalMat * in.Tangent);
    out.m_BiTangent = normalize(normalMat * in.BiTangent);

    return out;
}

// --- Fragment Shader ---

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              constant Uniforms& u [[buffer(1)]],
                              texture2d_array<float> u_Albedo    [[texture(0)]],
                              texture2d_array<float> u_Roughness [[texture(1)]],
                              texture2d_array<float> u_NormalMap [[texture(2)]],
                              texture2d<float>       SSAO        [[texture(3)]],
                              texturecube<float> diffuse_env     [[texture(4)]],
                              texturecube<float> specular_env    [[texture(5)]],
                              // Shadows
                              texture2d<float> sm0 [[texture(6)]],
                              texture2d<float> sm1 [[texture(7)]],
                              texture2d<float> sm2 [[texture(8)]],
                              texture2d<float> sm3 [[texture(9)]],
                              sampler sam [[sampler(0)]])
{
    int index = int(in.m_materialindex);

    // Roughness/Opacity/AO
    float4 roughSample = u_Roughness.sample(sam, in.tcord, index);
    float opacity = roughSample.r;
    if(opacity <= 0.1) discard_fragment();

    float currentRoughness = roughSample.g * u.Roughness;
    float currentAO = roughSample.b;

    // Normal Mapping
    float3 normalSample = u_NormalMap.sample(sam, in.tcord, index).rgb;
    normalSample = normalSample * 2.0 - 1.0;
    
    float3x3 TBN = float3x3(normalize(in.m_Tangent), normalize(in.m_BiTangent), normalize(in.m_Normal));
    float3 Modified_Normal;
    if (normalSample.z >= 0.99 && normalSample.x == 0.0) 
        Modified_Normal = normalize(in.m_Normal);
    else
        Modified_Normal = normalize(TBN * normalSample);

    // Shadows
    float4 vert_pos_view = u.view * in.m_pos;
    float depthVal = abs(vert_pos_view.z);
    
    int cascade_level = 3;
    for(int i = 0; i < 4; i++) {
        if(depthVal < u.Ranges[i]) {
            cascade_level = i;
            break;
        }
    }
    
    float4 lightSpacePos = u.MatrixShadow[cascade_level] * in.m_pos;
    float shadow = CalculateShadow(cascade_level, lightSpacePos, sm0, sm1, sm2, sm3, sam);

    // Lighting Setup
    float3 LightDir = normalize(-u.DirectionalLight_Direction);
    float3 EyeDir = normalize(u.EyePosition - in.m_pos.xyz);
    
    float3 Light_dir_i = reflect(-EyeDir, Modified_Normal);
    float vdoth_temp = max(dot(EyeDir, normalize(EyeDir + LightDir)), 0.0);
    
    float3 ks = Fresnel(vdoth_temp, u.Metallic, u.m_color.rgb, currentRoughness);
    float3 kd = (float3(1.0) - ks) * (1.0 - u.Metallic);

    // IBL
    float3 IBL_diffuse = diffuse_env.sample(sam, Modified_Normal).rgb * kd;
    float3 BRDFintegration = ks * currentRoughness + max(dot(Modified_Normal, LightDir), 0.001);
    
    // level() is the Metal equivalent of textureLod
    float3 IBL_specular = specular_env.sample(sam, Light_dir_i, level(MAX_MIP_LEVEL * currentRoughness)).rgb * BRDFintegration;
    
    float3 albedo = u_Albedo.sample(sam, in.tcord, index).rgb;
    float3 ambient = (IBL_diffuse + IBL_specular) * albedo * u.m_color.rgb;

    // Directional Light
    float3 PBR_Color = float3(0.0);
    
    float thread_vdoth; 
    float3 dirSpec = SpecularBRDF(LightDir, EyeDir, Modified_Normal, currentRoughness, u.Metallic, u.m_color.rgb, thread_vdoth);
    float3 dirDiff = (kd * albedo * u.m_color.rgb / PI);
    
    PBR_Color += (dirDiff + dirSpec) * shadow * max(dot(Modified_Normal, LightDir), 0.0);

    // Point Lights
    for(int i = 0; i < u.Num_PointLights; i++)
    {
        float3 ptPos = u.PointLight_Position[i].xyz;
        float3 ptCol = u.PointLight_Color[i].xyz;
        
        float3 L = normalize(ptPos - in.m_pos.xyz);
        
        float3 ptSpec = SpecularBRDF(L, EyeDir, Modified_Normal, currentRoughness, u.Metallic, u.m_color.rgb, thread_vdoth);
        
        float3 ptKs = Fresnel(thread_vdoth, u.Metallic, u.m_color.rgb, currentRoughness);
        float3 ptKd = (float3(1.0) - ptKs) * (1.0 - u.Metallic);
        
        float3 ptDiff = ptKd * albedo * u.m_color.rgb / PI;
        
        float dist = length(ptPos - in.m_pos.xyz);
        float atten = 1.0 / (0.01 * dist * dist);
        
        PBR_Color += (ptDiff + ptSpec) * ptCol * atten * max(dot(Modified_Normal, L), 0.00001);
    }

    PBR_Color += ambient;
    PBR_Color = ColorCorrection(PBR_Color);

    return float4(PBR_Color, 1.0);
}