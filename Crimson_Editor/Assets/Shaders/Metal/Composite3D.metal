#include <metal_stdlib>
using namespace metal;

// -------------------------------------------------------------------------
// CONSTANTS & STRUCTURES
// -------------------------------------------------------------------------
#define MAX_LIGHTS 100
#define MAX_MIP_LEVEL 28.0f
#define PI 3.14159265359f

struct VertexInput {
    float4 a_Position   [[attribute(0)]];
    float2 a_TexCoord   [[attribute(1)]];
    float3 a_Normal     [[attribute(2)]];
    float3 a_Tangent    [[attribute(3)]];
    float3 a_Bitangent  [[attribute(4)]];
    float  a_SlotIndex  [[attribute(5)]];
};

struct VertexOutput {
    float4 position [[position]]; // Clip-space position
    float4 worldPos;              // World-space position (v_Position)
    float2 texCoord;
    float3 normal;
    float3 tangent;
    float3 bitangent;
    uint   slotIndex [[flat]];    // "flat out" in GLSL
};

// Uniform Buffer (Must match CPU padding!)
struct Uniforms {
    float4x4 u_ProjectionView;
    float4x4 u_Model;
    float4x4 view;
    
    // Shadows
    // Note: Arrays of matrices are fine.
    float4x4 ShadowMatrices[4];
    // Note: Arrays of floats in Metal buffer must be 16-byte aligned usually, 
    // but simple float arrays work if packed carefully. 
    // Ideally pass float4 for alignment or use packed_float.
    float ShadowRanges[5]; 

    // Material & Eye
    float4 m_color;
    float3 EyePosition;
    float  u_depth; // padding likely needed here in C++ struct

    // Lighting
    float3 DirectionalLight_Direction;
    float  SunLight_Intensity;
    float3 SunLight_Color;
    
    // PBR
    float Roughness;
    float Metallic;
    float Transparency;
    int   Num_PointLights;

    // Point Lights
    // WARNING: float3 arrays in Metal buffers are strided as float4 (16 bytes). 
    // Ensure your C++ sends vec4 (x,y,z,padding) for positions and colors.
    float4 PointLight_Positions[MAX_LIGHTS]; 
    float4 PointLight_Colors[MAX_LIGHTS];
};

// -------------------------------------------------------------------------
// HELPER FUNCTIONS
// -------------------------------------------------------------------------

// GGX Normal Distribution
float NormalDistribution_GGX(float NdotH, float alpha) {
    float alpha2 = pow(alpha, 4.0);
    float denom = (pow(NdotH, 2.0) * (alpha2 - 1.0) + 1.0);
    return alpha2 / (PI * pow(denom, 2.0));
}

// GGX Geometry
float Geometry_GGX(float dp, float alpha) {
    float k = pow(alpha + 1.0, 2.0) / 8.0;
    return dp / (dp * (1.0 - k) + k);
}

// Fresnel-Schlick
float3 Fresnel(float VdotH, float metallic) {
    float3 f0 = (metallic == 0.0) ? float3(0.04) : float3(0.4);
    return f0 + (1.0 - f0) * pow(clamp(1.0 - VdotH, 0.0, 1.0), 5.0);
}

// Specular BRDF
float3 SpecularBRDF(float3 LightDir, float3 ViewDir, float3 Normal, float alpha, float metallic) {
    float3 Half = normalize(ViewDir + LightDir);
    float NdotH = max(dot(Normal, Half), 0.0);
    float NdotV = max(dot(Normal, ViewDir), 0.000001);
    float NdotL = max(dot(Normal, LightDir), 0.000001);
    float VdotH = max(dot(ViewDir, Half), 0.0);

    float Dggx = NormalDistribution_GGX(NdotH, alpha);
    float Gggx = Geometry_GGX(NdotV, alpha) * Geometry_GGX(NdotL, alpha);
    float3 fresnel = Fresnel(VdotH, metallic);

    float denominator = 4.0 * NdotL * NdotV + 0.0001;
    return (Dggx * Gggx * fresnel) / denominator;
}

// Shadow Calculation
// Note: We must pass textures explicitly. Metal cannot index array of textures dynamically easily
float CalculateShadow(int level, float4 lightSpacePos, 
                      texture2d<float> shadowMap0, 
                      texture2d<float> shadowMap1, 
                      texture2d<float> shadowMap2, 
                      texture2d<float> shadowMap3,
                      sampler sam) 
{
    float3 p = lightSpacePos.xyz / lightSpacePos.w;
    p = p * 0.5 + 0.5; // Convert to [0, 1]
    
    // Reverse Y for Metal if your Shadow Map generation didn't flip it already
    // Usually shadow maps in Metal need Y flipped compared to OpenGL
    p.y = 1.0 - p.y; 

    float bias = 0.00001;
    float shadowSum = 0.0;
    
    // Select the correct map
    texture2d<float> selectedMap;
    if (level == 0) selectedMap = shadowMap0;
    else if (level == 1) selectedMap = shadowMap1;
    else if (level == 2) selectedMap = shadowMap2;
    else selectedMap = shadowMap3;

    float2 texelSize = 1.0 / float2(selectedMap.get_width(), selectedMap.get_height());

    // PCF Loop
    for(int i = -1; i <= 1; i++) {
        for(int j = -1; j <= 1; j++) {
            float2 offset = float2(i, j) * texelSize;
            // Sample red channel for depth
            float depth = selectedMap.sample(sam, p.xy + offset).r;
            
            // Comparison (Standard GLSL style)
            // Note: In Metal, Z runs 0 to 1. Check your projection matrices.
            if(depth + bias > p.z) {
                shadowSum += 1.0;
            }
        }
    }

    return shadowSum / 9.0;
}

// Normal Mapping
float3 NormalMapping(float3 normal, float3 tangent, float3 bitangent, float2 texCoord, int index, 
                     texture2d_array<float> normalMap, sampler sam) 
{
    float3 mapNormal = normalMap.sample(sam, texCoord, index).rgb;
    mapNormal = mapNormal * 2.0 - 1.0;

    // TBN Matrix
    float3x3 TBN = float3x3(tangent, bitangent, normal);

    // If normal map is essentially white (z-up), skip
    if (mapNormal.z >= 0.99 && mapNormal.x == 0 && mapNormal.y == 0)
        return normal;
    
    return normalize(TBN * mapNormal);
}


// -------------------------------------------------------------------------
// VERTEX SHADER
// -------------------------------------------------------------------------
vertex VertexOutput vertex_main(VertexInput in [[stage_in]],
                                constant Uniforms& uniforms [[buffer(1)]])
{
    VertexOutput out;

    // Model Matrix Transform
    float4 worldPos = uniforms.u_Model * in.a_Position;
    out.worldPos = worldPos;
    
    // Projection * View * Model
    out.position = uniforms.u_ProjectionView * worldPos;

    out.texCoord = in.a_TexCoord;
    out.slotIndex = uint(in.a_SlotIndex);

    // Normal Transform (Inverse Transpose of Model Top-Left 3x3)
    // For uniform scaling, just casting to float3x3 works.
    float3x3 normalMat = float3x3(uniforms.u_Model[0].xyz, uniforms.u_Model[1].xyz, uniforms.u_Model[2].xyz);
    
    out.normal = normalize(normalMat * in.a_Normal);
    out.tangent = normalize(normalMat * in.a_Tangent);
    out.bitangent = normalize(normalMat * in.a_Bitangent);

    return out;
}


// -------------------------------------------------------------------------
// FRAGMENT SHADER
// -------------------------------------------------------------------------
fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              constant Uniforms& u [[buffer(1)]],
                              
                              // Textures
                              texture2d_array<float> u_Albedo    [[texture(0)]],
                              texture2d_array<float> u_Roughness [[texture(1)]],
                              texture2d_array<float> u_NormalMap [[texture(2)]],
                              texture2d<float>       SSAO        [[texture(3)]],
                              
                              // Cubemaps
                              texturecube<float> diffuse_env  [[texture(4)]],
                              texturecube<float> specular_env [[texture(5)]],
                              
                              // Shadow Maps (Separate slots)
                              texture2d<float> shadowMap0 [[texture(6)]],
                              texture2d<float> shadowMap1 [[texture(7)]],
                              texture2d<float> shadowMap2 [[texture(8)]],
                              texture2d<float> shadowMap3 [[texture(9)]],
                              
                              // Samplers (You can use one common sampler or separate ones)
                              sampler sam [[sampler(0)]])
{
    // Unpack Inputs
    int index = int(in.slotIndex);
    float3 N = normalize(in.normal);
    float3 T = normalize(in.tangent);
    float3 B = normalize(in.bitangent);
    
    // Normal Mapping
    float3 Modified_Normal = NormalMapping(N, T, B, in.texCoord, index, u_NormalMap, sam);

    // Roughness
    // Multiply by texture.r
    float currentRoughness = u_Roughness.sample(sam, in.texCoord, index).r * u.Roughness;

    // Cascade Selection
    // Calculate depth in view space
    float4 vert_pos_view = u.view * in.worldPos;
    float depthVal = abs(vert_pos_view.z);
    
    int level = 3;
    for(int i = 0; i < 4; i++) {
        if(depthVal < u.ShadowRanges[i]) {
            level = i;
            break;
        }
    }

    // Shadow Calculation
    float4 lightSpacePos = u.ShadowMatrices[level] * in.worldPos;
    float shadow = CalculateShadow(level, lightSpacePos, shadowMap0, shadowMap1, shadowMap2, shadowMap3, sam);

    // Lighting Vectors
    float3 EyeDirection = normalize(u.EyePosition - in.worldPos.xyz);
    float3 LightDirection = normalize(-u.DirectionalLight_Direction);
    
    // Environment Mapping (IBL)
    float3 Light_dir_i = reflect(-EyeDirection, Modified_Normal);
    float VdotH = max(dot(EyeDirection, normalize(EyeDirection + LightDirection)), 0.0);
    
    float3 ks = Fresnel(VdotH, u.Metallic);
    float3 kd = (float3(1.0) - ks) * (1.0 - u.Metallic);
    
    float3 IBL_diffuse = diffuse_env.sample(sam, Modified_Normal).rgb * kd;
    
    // Note: BRDF integration term usually requires a LUT, here simplified as per your GLSL
    float BRDFintegration = ks.r * currentRoughness + max(dot(Modified_Normal, LightDirection), 0.001); 
    
    // LOD sampling for specular cube
    float3 IBL_specular = specular_env.sample(sam, Light_dir_i, level(MAX_MIP_LEVEL * currentRoughness)).rgb * BRDFintegration;
    
    // Ambient Term
    // SSAO sampling (Project to Screen Space)
    float4 projCoords = u.u_ProjectionView * in.worldPos;
    projCoords.xy /= projCoords.w;
    float2 ssaoUV = projCoords.xy * 0.5 + 0.5;
    ssaoUV.y = 1.0 - ssaoUV.y; // Metal flip Y
    
    float3 albedoSample = u_Albedo.sample(sam, in.texCoord, index).rgb;
    float ssaoVal = SSAO.sample(sam, ssaoUV).r;
    
    float3 ambient = (IBL_diffuse + IBL_specular) * albedoSample * u.m_color.rgb * ssaoVal;

    // Direct Lighting (Sun)
    float3 PBR_Color = float3(0.0);
    
    float NdotL = max(dot(Modified_Normal, LightDirection), 0.0);
    
    float3 sunSpec = SpecularBRDF(LightDirection, EyeDirection, Modified_Normal, currentRoughness, u.Metallic);
    float3 sunDiff = (kd * albedoSample * u.m_color.rgb / PI);
    
    PBR_Color += (sunDiff + sunSpec) * (shadow * u.SunLight_Color * u.SunLight_Intensity) * NdotL;

    // Point Lights
    for(int i = 0; i < u.Num_PointLights; i++) 
    {
        // Remember to access xyz from the padded float4
        float3 ptPos = u.PointLight_Positions[i].xyz;
        float3 ptCol = u.PointLight_Colors[i].xyz;

        float3 ptLightDir = normalize(ptPos - in.worldPos.xyz);
        float dist = length(ptPos - in.worldPos.xyz);
        float attenuation = 1.0 / (0.01 * dist * dist);
        
        float3 ptSpec = SpecularBRDF(ptLightDir, EyeDirection, Modified_Normal, currentRoughness, u.Metallic);
        
        // Recalculate Fresnel for point light geometry
        float3 H = normalize(EyeDirection + ptLightDir);
        float ptVdotH = max(dot(EyeDirection, H), 0.0);
        float3 ptKs = Fresnel(ptVdotH, u.Metallic);
        float3 ptKd = (float3(1.0) - ptKs) * (1.0 - u.Metallic);
        
        float3 ptDiff = ptKd * albedoSample * u.m_color.rgb / PI;
        
        PBR_Color += (ptDiff + ptSpec) * ptCol * attenuation * max(dot(ptLightDir, Modified_Normal), 0.0);
    }

    // Final Combine
    return float4(PBR_Color + ambient, 1.0);
}