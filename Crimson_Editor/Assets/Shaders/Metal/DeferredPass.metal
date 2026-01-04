#include <metal_stdlib>
using namespace metal;

#define MAX_LIGHTS 100
#define PI 3.14159265359f
#define MAX_MIP_LEVEL 4.0f

// -------------------------------------------------------------------------
// STRUCTS
// -------------------------------------------------------------------------

struct VertexInput {
    float4 position [[attribute(0)]];
    float4 cord     [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 tcord;
};

// Must match the memory layout of C++ Uniforms buffer
struct Uniforms {
    float jitterX;
    float jitterY;
    
    // Shadows
    float4x4 MatrixShadow[4];
    float Ranges[5]; 
    
    float4x4 u_View;
    float4x4 u_Projection;
    
    // --- ADDED INVERSES todo / to fix add to C++ side ---
    float4x4 u_InverseView;
    float4x4 u_InverseProjection;
    
    float3 EyePosition;
    
    // Lighting
    float3 DirectionalLight_Direction;
    float3 SunLight_Color;
    float SunLight_Intensity;
    
    // Point Lights
    float4 PointLight_Position[MAX_LIGHTS]; 
    float4 PointLight_Color[MAX_LIGHTS];
    int Num_PointLights;
};

// -------------------------------------------------------------------------
// HELPER FUNCTIONS 
// -------------------------------------------------------------------------

float CalculateShadow(int cascade_level, float4 VertexPosition_LightSpace, 
                      texture2d<float> sm0, texture2d<float> sm1, 
                      texture2d<float> sm2, texture2d<float> sm3, sampler sam)
{
    float3 p = VertexPosition_LightSpace.xyz / VertexPosition_LightSpace.w;
    p = p * 0.5 + 0.5; 
    p.y = 1.0 - p.y;   

    float bias = 0.0001;
    float ShadowSum = 0.0;
    
    texture2d<float> map;
    if (cascade_level == 0) map = sm0;
    else if (cascade_level == 1) map = sm1;
    else if (cascade_level == 2) map = sm2;
    else map = sm3;
    
    float2 TexelSize = 1.0 / float2(map.get_width(), map.get_height());

    for(int i = -1; i <= 1; i++) {
        for(int j = -1; j <= 1; j++) {
            float2 offset = float2(i, j) * TexelSize;
            float depth = map.sample(sam, p.xy + offset).r;
            if (depth + bias > p.z)
                ShadowSum += 1.0;
        }
    }
    return ShadowSum / 9.0;
}

float NormalDistribution_GGX(float NdotH, float roughness) {
    float alpha2 = pow(roughness, 4.0);
    float denom = (pow(NdotH, 2.0) * (alpha2 - 1.0) + 1.0);
    return alpha2 / (PI * pow(denom, 2.0));
}

float Geometry_GGX(float dp, float roughness) {
    float k = pow(roughness + 1.0, 2.0) / 8.0;
    return dp / (dp * (1.0 - k) + k);
}

float3 Fresnel(float VdotH, float3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - VdotH, 0.0, 1.0), 5.0);
}

float3 FresnelSchlickRoughness(float VdotH, float roughness, float3 F0) {
    return F0 + (max(float3(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - VdotH, 0.0, 1.0), 5.0);
}

float3 SpecularBRDF(float3 LightDir, float3 ViewDir, float3 Normal, float roughness, float3 F0) {
    float3 Half = normalize(ViewDir + LightDir);
    float NdotH = max(dot(Normal, Half), 0.0);
    float NdotV = max(dot(Normal, ViewDir), 0.000001);
    float NdotL = max(dot(Normal, LightDir), 0.000001);
    float VdotH = max(dot(ViewDir, Half), 0.0);

    float Dggx = NormalDistribution_GGX(NdotH, roughness);
    float Gggx = Geometry_GGX(NdotV, roughness) * Geometry_GGX(NdotL, roughness);
    float3 fresnel = Fresnel(VdotH, F0);

    float denominator = 4.0 * NdotL * NdotV + 0.0001;
    return (Dggx * Gggx * fresnel) / denominator;
}

// -------------------------------------------------------------------------
// VERTEX SHADER 
// -------------------------------------------------------------------------
vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                                constant Uniforms& u [[buffer(1)]])
{
    VertexOutput out;
    float4 clip_space = in.position;
    clip_space += float4(u.jitterX * clip_space.w, u.jitterY * clip_space.w, 0.0, 0.0);
    out.position = clip_space;
    out.tcord = in.cord.xy;
    return out;
}

// -------------------------------------------------------------------------
// FRAGMENT SHADER
// -------------------------------------------------------------------------
fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              constant Uniforms& u [[buffer(1)]],
                              
                              texture2d<float> depthBuffer        [[texture(0)]],
                              texture2d<float> gNormal            [[texture(1)]],
                              texture2d<float> gVelocity          [[texture(2)]],
                              texture2d<float> gColor             [[texture(3)]],
                              texture2d<float> gRoughnessMetallic [[texture(4)]],
                              texture2d<float> History_Buffer     [[texture(5)]],
                              
                              texture2d<float> sm0 [[texture(6)]],
                              texture2d<float> sm1 [[texture(7)]],
                              texture2d<float> sm2 [[texture(8)]],
                              texture2d<float> sm3 [[texture(9)]],
                              
                              texturecube<float> diffuse_env  [[texture(10)]],
                              texturecube<float> specular_env [[texture(11)]],
                              texture2d<float>   BRDF_LUT     [[texture(12)]],
                              texture2d<float>   SSAO         [[texture(13)]],
                              
                              sampler sam [[sampler(0)]])
{
    float z = depthBuffer.sample(sam, in.tcord).r;
    
    if(z == 1.0) discard_fragment();

    float4 clip_space = float4(in.tcord * 2.0 - 1.0, z * 2.0 - 1.0, 1.0);
    
    float4 view_space = u.u_InverseProjection * clip_space;
    view_space /= view_space.w;
    
    float4 world_space = u.u_InverseView * view_space;
    float4 m_pos = float4(world_space.xyz, 1.0);

    // Reconstruct World Normal
    float3 encodedNormal = gNormal.sample(sam, in.tcord).xyz;
    
    float3x3 inverseViewRot = float3x3(u.u_InverseView[0].xyz, 
                                   u.u_InverseView[1].xyz, 
                                   u.u_InverseView[2].xyz);

    float3 Modified_Normal = normalize(inverseViewRot * encodedNormal);

    // Material Properties
    float4 m_Color = gColor.sample(sam, in.tcord);
    float4 RoughnessMetallic = gRoughnessMetallic.sample(sam, in.tcord);
    float alpha = RoughnessMetallic.r;
    float Metallic = RoughnessMetallic.g;

    // Shadow Cascade Calculation
    float depthVal = abs(view_space.z);
    int cascade_level = 3;
    for(int i = 0; i < 4; i++) {
        if(depthVal < u.Ranges[i]) {
            cascade_level = i;
            break;
        }
    }
    float4 VertexPosition_LightSpace = u.MatrixShadow[cascade_level] * m_pos;
    float shadow = CalculateShadow(cascade_level, VertexPosition_LightSpace, sm0, sm1, sm2, sm3, sam);

    // Lighting Setup
    float3 DirectionalLight_Dir = normalize(-u.DirectionalLight_Direction);
    float3 EyeDirection = normalize(u.EyePosition - m_pos.xyz);
    float3 Light_dir_i = reflect(-EyeDirection, Modified_Normal);

    float3 F0 = float3(0.04);
    F0 = mix(F0, m_Color.xyz, Metallic);

    // --- AMBIENT / IBL ---
    float ndotv = max(dot(EyeDirection, Modified_Normal), 0.0);
    float3 ks = FresnelSchlickRoughness(ndotv, alpha, F0);
    float3 kd = (float3(1.0) - ks) * (1.0 - Metallic);

    float3 IBL_diffuse = diffuse_env.sample(sam, Modified_Normal).rgb * kd;
    
    float2 BRDF_pt = float2(max(dot(Modified_Normal, EyeDirection), 0.0), alpha);
    float2 BRDFintegration = BRDF_LUT.sample(sam, BRDF_pt).rg;
    
    float3 IBL_specular = specular_env.sample(sam, Light_dir_i, level(MAX_MIP_LEVEL * alpha)).rgb * (ks * BRDFintegration.x + BRDFintegration.y);
    
    float ao = SSAO.sample(sam, in.tcord).r;
    float3 ambient = (IBL_diffuse * m_Color.xyz + IBL_specular) * pow(ao, 1.0);

    // --- SUN LIGHT ---
    float3 PBR_Color = float3(0.0);
    
    float vdoth = max(dot(EyeDirection, normalize(DirectionalLight_Dir + EyeDirection)), 0.0);
    ks = Fresnel(vdoth, F0);
    kd = (float3(1.0) - ks) * (1.0 - Metallic);
    
    float3 sunSpec = SpecularBRDF(DirectionalLight_Dir, EyeDirection, Modified_Normal, alpha, F0);
    PBR_Color += ((kd * m_Color.xyz / PI) + sunSpec) * (shadow * u.SunLight_Color * u.SunLight_Intensity) * max(dot(Modified_Normal, DirectionalLight_Dir), 0.001);

    // --- POINT LIGHTS ---
    for(int i = 0; i < u.Num_PointLights; i++)
    {
        float3 lightPos = u.PointLight_Position[i].xyz;
        float3 lightCol = u.PointLight_Color[i].xyz;
        
        float3 LightDirection = normalize(lightPos - m_pos.xyz);
        float3 H = normalize(LightDirection + EyeDirection);
        
        float3 specular = SpecularBRDF(LightDirection, EyeDirection, Modified_Normal, alpha, F0);
        ks = Fresnel(max(dot(H, EyeDirection), 0.0), F0);
        
        kd = (float3(1.0) - ks) * (1.0 - Metallic);
        float3 diffuse = kd * m_Color.xyz / PI;
        
        float dist = length(lightPos - m_pos.xyz);
        float attenuation = 1.0 / (0.01 * dist * dist);
        float3 radiance = lightCol * attenuation;
        
        float NdotL = max(dot(Modified_Normal, LightDirection), 0.1);
        PBR_Color += (diffuse + specular) * radiance * NdotL;
    }

    PBR_Color += ambient;

    // --- COLOR CORRECTION ---
    PBR_Color = float3(1.0) - exp(-PBR_Color * 1.1);
    PBR_Color = mix(float3(dot(PBR_Color, float3(0.299, 0.587, 0.114))), PBR_Color, 1.0);
    PBR_Color = 1.03 * (PBR_Color - 0.5) + 0.5;

    return float4(PBR_Color, 1.0);
}