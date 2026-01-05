#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float4 pos  [[attribute(0)]];
    float4 cord [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 tcord;
    float3 m_pos;
};

struct FogUniforms {
    float4x4 u_Projection;
    float4x4 u_View;
    float4x4 u_InvProjection; // pre-calculate on cpu for performance
    float4x4 u_InvView;       // pre-calculate on cpu for performance
    float3 u_CamDir;
    float u_density;
    float u_gradient;
    float3 u_fogColor;
    float u_fogTop;
    float u_fogEnd;
    float3 u_CamPos;
    float3 u_sunDir;
    float3 u_ViewDir;
};

vertex VertexOutput vertex_main(VertexInput in [[stage_in]])
{
    VertexOutput out;
    out.position = in.pos;
    out.m_pos = in.pos.xyz;
    out.tcord = in.cord.xy;
    return out;
}

float4 GetWorldPosition(float2 texCoord, 
                        depth2d<float> sceneDepth, 
                        constant FogUniforms& u,
                        sampler s)
{
    float z = sceneDepth.sample(s, texCoord);
    
    // transform from 0..1 uv and depth to -1..1 clip space
    float4 clip_space = float4(texCoord * 2.0 - 1.0, z * 2.0 - 1.0, 1.0);
    
    float4 viewSpace = u.u_InvProjection * clip_space;
    viewSpace /= viewSpace.w;
    
    float4 worldSpace = u.u_InvView * viewSpace;
    return worldSpace;
}

float GetFogDensity(float2 tcord, 
                    depth2d<float> sceneDepth, 
                    constant FogUniforms& u, 
                    sampler s)
{
    float3 proj_CameraPos = u.u_CamPos;
    proj_CameraPos.y = 0.0;

    float3 WorldPos = GetWorldPosition(tcord, sceneDepth, u, s).xyz;

    float3 ws_PixelPos = WorldPos;
    ws_PixelPos.y = 0.0;

    float DeltaD = length(proj_CameraPos - ws_PixelPos) / u.u_fogEnd;
    float DeltaY = 0.0;
    float DensityIntegral = 0.0;

    if (u.u_CamPos.y > u.u_fogTop) 
    {
        // camera above fog
        if (WorldPos.y < u.u_fogTop) 
        {
            // pixel inside fog
            DeltaY = (u.u_fogTop - WorldPos.y) / u.u_fogTop;
            DensityIntegral = DeltaY * DeltaY * 0.5;
        }
    }
    else if (WorldPos.y < u.u_fogTop) 
    {
        // camera inside fog, pixel inside fog
        DeltaY = abs(u.u_CamPos.y - WorldPos.y) / u.u_fogTop;
        float deltaCamera = (u.u_fogTop - u.u_CamPos.y) / u.u_fogTop;
        float densityIntegralCamera = deltaCamera * deltaCamera * 0.5;
        float deltaPixel = (u.u_fogTop - WorldPos.y) / u.u_fogTop;
        float densityIntegralPixel = deltaPixel * deltaPixel * 0.5;
        DensityIntegral = abs(densityIntegralCamera - densityIntegralPixel);
    }
    else 
    {
        // camera inside fog, pixel above fog
        DeltaY = (u.u_fogTop - u.u_CamPos.y) / u.u_fogTop;
        DensityIntegral = DeltaY * DeltaY * 0.5;
    }

    float fogDensity = 0.0;
    if (DeltaY != 0.0)
    {
        float ratio = DeltaD / DeltaY;
        fogDensity = sqrt(1.0 + (ratio * ratio)) * DensityIntegral;
    }
    return fogDensity;
}

fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              constant FogUniforms& u     [[buffer(1)]],
                              depth2d<float> u_sceneDepth [[texture(0)]],
                              texture2d<float> u_sceneColor [[texture(1)]],
                              sampler s [[sampler(0)]])
{
    float fogDensity = pow(GetFogDensity(in.tcord, u_sceneDepth, u, s), u.u_density);

    float3 pixelWorldPos = GetWorldPosition(in.tcord, u_sceneDepth, u, s).xyz;
    
    // sun scattering approximation
    float sunAmount = max(dot(normalize(pixelWorldPos - u.u_CamPos), normalize(-u.u_sunDir)), 0.0);
    float scattering_gradient = exp(pow(sunAmount, 64.0) * 0.15); 
    
    

    float3 fogColor = mix(u.u_fogColor,
                          float3(1.0, 0.8, 0.5), // sun halo color
                          pow(sunAmount, 4.0));
                          
    float3 sceneColorRaw = u_sceneColor.sample(s, in.tcoord).rgb;
    
    // blend scene and fog
    float fogFactor = exp(-fogDensity);
    float3 finalColor = fogColor * (1.0 - fogFactor) + sceneColorRaw * fogFactor;
    
    return float4(finalColor * scattering_gradient, 1.0);
}