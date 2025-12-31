#shader vertex
#version 410 core

// Input attributes for vertex position, texture coordinates, normal, tangent, bitangent, and slot index
layout (location = 0) in vec4 a_Position;
layout (location = 1) in vec2 a_TexCoord;
layout (location = 2) in vec3 a_Normal;
layout (location = 3) in vec3 a_Tangent;
layout (location = 4) in vec3 a_Bitangent;
layout (location = 5) in float a_SlotIndex;

// Output variables for the fragment shader
out vec2 v_TexCoord;
out vec4 v_Position;
out vec3 v_Normal;
out vec3 v_Tangent;
out vec3 v_Bitangent;
flat out float v_SlotIndex;

// Uniforms for projection-view and model matrices
uniform mat4 u_ProjectionView;  // Projection-view matrix
uniform mat4 u_Model;  // Model matrix

void main()
{
    // Apply transformation to vertex position
    gl_Position = u_ProjectionView * u_Model * a_Position;

    // Pass data to fragment shader
    v_SlotIndex = a_SlotIndex;
    v_TexCoord = a_TexCoord;
    v_Normal = normalize(mat3(u_Model) * a_Normal);
    v_Tangent = normalize(mat3(u_Model) * a_Tangent);
    v_Bitangent = normalize(mat3(u_Model) * a_Bitangent);
    v_Position = u_Model * a_Position;
}










#shader fragment
#version 410 core

// Output color for the fragment shader
layout (location = 0) out vec4 fragColor;

// Input data from vertex shader
in vec4 v_Position;
in vec3 v_Normal;
in vec3 v_Tangent;
in vec3 v_Bitangent;
flat in float v_SlotIndex;
in vec2 v_TexCoord;

// Constants for shadow calculation
#define MAX_LIGHTS 100
vec4 LightSpacePosition;  // Position of the vertex in light space

// Uniforms for shadow mapping and lighting
uniform mat4 ShadowMatrices[4];  // Shadow transformation matrices
uniform sampler2D ShadowMaps[4];  // Shadow map textures
uniform float ShadowRanges[5];  // Shadow range values
uniform mat4 view;  // View matrix
uniform mat4 u_ProjectionView;  // Projection-view matrix

// Environment maps and texture samplers
uniform samplerCube diffuse_env;
uniform samplerCube specular_env;
uniform sampler2D SSAO;  // Ambient occlusion map
uniform sampler2DArray u_Albedo;  // Albedo texture array
uniform sampler2DArray u_Roughness;  // Roughness texture array
uniform sampler2DArray u_NormalMap;  // Normal map texture array
uniform float u_depth;  // Depth value

// Eye position and material properties
uniform vec3 EyePosition;
uniform vec4 m_color;  // Base color of the material

// Light properties
uniform vec3 DirectionalLight_Direction;  // Direction of the directional light (sun)
uniform vec3 SunLight_Color;  // Color of the sun
uniform float SunLight_Intensity;  // Intensity of the sun
uniform vec3 PointLight_Positions[MAX_LIGHTS];  // Positions of point lights
uniform vec3 PointLight_Colors[MAX_LIGHTS];  // Colors of point lights
uniform int Num_PointLights;  // Number of point lights

// PBR material properties
uniform float Roughness;
uniform float Metallic;
uniform float Transparency;
float ao = 1.0;

vec3 PBR_Color = vec3(0.0);  // Final PBR color
vec3 radiance;  // Radiance for point light

vec3 ks;  // Specular reflection
vec3 kd;  // Diffuse reflection
float vdoth;  // Dot product of view and half vector

float alpha = Roughness;  // Roughness value
const float PI = 3.14159265359;  // Pi constant
#define MAX_MIP_LEVEL 28  // Maximum mipmap level for environment map sampling

int level = 3;  // Cascade level for shadows

// Normal mapping function
vec3 NormalMapping(int index) // index implies which material index normal map to use
{
    vec3 normal = texture(u_NormalMap , vec3(v_TexCoord, index)).rgb;
    normal = normal * 2.0 - 1.0;  // Convert to [-1, 1] range
    mat3 TBN = mat3(v_Tangent, v_Bitangent, v_Normal);
    if(normal == vec3(1.0))  // If normal map is white, use vertex normal
        return v_Normal;
    else
        return normalize(TBN * normal);  // Transform normal to world space
}

// Shadow calculation function
float CalculateShadow(int cascade_level)
{
    float ShadowSum = 0.0;
    vec3 p = LightSpacePosition.xyz / LightSpacePosition.w;
    p = p * 0.5 + 0.5;  // Convert to [0, 1] for texture mapping
    float bias = 0.00001;  // Bias to reduce artifacts
    float TexelSize = 1.0 / textureSize(ShadowMaps[cascade_level], 0).x;

    // Sample surrounding texels for shadow computation
    for(int i = -1; i <= 1; i++)
    {
        for(int j = -1; j <= 1; j++)
        {
            vec2 offset = vec2(i, j) * TexelSize;
            float depth = texture(ShadowMaps[cascade_level], p.xy + offset).r;
            if(depth + bias > p.z)
                ShadowSum += 1;
        }
    }

    return ShadowSum / 9.0;  // Average the shadow samples
}

// GGX normal distribution function
float NormalDistribution_GGX(float NdotH)
{
    float alpha2 = pow(alpha, 4);
    return alpha2 / (PI * pow((pow(NdotH, 2) * (alpha2 - 1.0) + 1.0), 4));
}

// GGX geometry function
float Geometry_GGX(float dp)
{
    float k = pow(alpha + 1, 2) / 8.0;
    return dp / (dp * (1 - k) + k);
}

// Fresnel-Schlick approximation for specular reflection
vec3 Fresnel(float VdotH)
{
    vec3 f0 = (Metallic == 0.0) ? vec3(0.04) : vec3(0.4);
    return f0 + (1.0 - f0) * pow(clamp(1.0 - VdotH, 0.0, 1.0), 5.0);
}

// Specular BRDF (Bidirectional Reflectance Distribution Function)
vec3 SpecularBRDF(vec3 LightDir, vec3 ViewDir, vec3 Normal)
{
    vec3 Half = normalize(ViewDir + LightDir);
    float NdotH = max(dot(Normal, Half), 0.0);
    float NdotV = max(dot(Normal, ViewDir), 0.000001);
    float NdotL = max(dot(Normal, LightDir), 0.000001);
    float VdotH = max(dot(ViewDir, Half), 0.0);

    vdoth = VdotH;

    float Dggx = NormalDistribution_GGX(NdotH);
    float Gggx = Geometry_GGX(NdotV) * Geometry_GGX(NdotL);
    vec3 fresnel = Fresnel(VdotH);

    float denominator = 4.0 * NdotL * NdotV + 0.0001;
    vec3 specular = (Dggx * Gggx * fresnel) / denominator;
    return specular;
}

// Color correction function
vec3 ColorCorrection(vec3 color)
{
    color = clamp(color, 0.0, 1.0);
    color = pow(color, vec3(1.0 / 2.2));  // Gamma correction

    color = clamp(color, 0.0, 1.0);
    color = vec3(1.0) - exp(-color * 2);  // Exposure adjustment

    color = clamp(color, 0.0, 1.0);
    color = 1.3 * (color - 0.5) + 0.5 + 0.08;  // Contrast adjustment

    return color;
}

void main()
{
    // Fetch the normal from the normal map
    int index = int(v_SlotIndex);
    vec3 Modified_Normal = NormalMapping(index);

    // Update roughness using the texture
    alpha = texture(u_Roughness, vec3(v_TexCoord, index)).r * Roughness;

    // Calculate the depth value in the camera space
    vec4 vert_pos = view * v_Position;  // Get depth in camera space
    vec3 v_position = vert_pos.xyz / vert_pos.w;
    float depth = abs(v_position.z);

    // Determine cascade level for shadows based on depth
    for(int i = 0; i < 4; i++)
    {
        if(depth < ShadowRanges[i])
        {
            level = i;
            break;
        }
    }

    LightSpacePosition = ShadowMatrices[level] * v_Position;

    // Directional light properties
    vec3 DirectionalLight_Direction = normalize(-DirectionalLight_Direction);  // Directional light has no position
    vec3 EyeDirection = normalize(EyePosition - v_Position.xyz / v_Position.w);

    float shadow = CalculateShadow(level);

    // Reflection for environment mapping
    vec3 Light_dir_i = reflect(-EyeDirection, Modified_Normal);
    vdoth = max(dot(EyeDirection, normalize(EyeDirection + DirectionalLight_Direction)), 0.0);
    ks = Fresnel(vdoth);
    kd = vec3(1.0) - ks;
    kd *= (1.0 - Metallic);

    // Diffuse and specular components from environment map
    vec3 IBL_diffuse = texture(diffuse_env, Modified_Normal).rgb * kd;
    vec3 BRDFintegration = ks * alpha + max(dot(Modified_Normal, DirectionalLight_Direction), 0.001);
    vec3 IBL_specular = textureLod(specular_env, Light_dir_i, MAX_MIP_LEVEL * alpha).rgb * BRDFintegration;

    // Ambient light contribution
    vec4 coordinate = u_ProjectionView * v_Position;
    coordinate.xyz /= coordinate.w;
    coordinate.xyz = coordinate.xyz * 0.5 + 0.5;
    vec3 ambiant = (IBL_diffuse + IBL_specular) * texture(u_Albedo, vec3(v_TexCoord, index)).xyz * m_color.xyz * texture(SSAO, coordinate.xy).r;

    // Combine PBR color with directional light and shadow
    PBR_Color += ((kd * texture(u_Albedo, vec3(v_TexCoord, index)).xyz * m_color.xyz / PI) + SpecularBRDF(DirectionalLight_Direction, EyeDirection, Modified_Normal)) * (shadow * SunLight_Color * SunLight_Intensity) * max(dot(Modified_Normal, DirectionalLight_Direction), 0.0);

    // Process point lights
    for(int i = 0; i < Num_PointLights; i++)
    {
        vec3 LightDirection = normalize(PointLight_Positions[i] - v_Position.xyz / v_Position.w);
        vec3 specular = SpecularBRDF(LightDirection, EyeDirection, Modified_Normal);
        ks = Fresnel(vdoth);

        kd = vec3(1.0) - ks;
        kd *= (1.0 - Metallic);
        vec3 diffuse = kd * texture(u_Albedo, vec3(v_TexCoord, index)).xyz * m_color.xyz / PI;

        // Attenuation for point lights
        float dist = length(PointLight_Positions[i] - v_Position.xyz / v_Position.w);
        float attenuation = 1 / (0.01 * dist * dist);
        radiance = PointLight_Colors[i] * attenuation;

        PBR_Color += (diffuse + specular) * radiance * max(dot(LightDirection, Modified_Normal), 0.0);
    }

    // Final color after light contributions
    fragColor = vec4(PBR_Color + ambiant, 1.0);
}
