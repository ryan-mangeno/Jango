#include <metal_stdlib>
using namespace metal;


constant float DEG2RAD = 0.01745329251f; // PI / 180

struct VertexInput {
    float4 pos       [[attribute(0)]];
    float2 cord      [[attribute(1)]];
    float3 Normal    [[attribute(2)]];
    float3 Tangent   [[attribute(3)]];
    float3 BiTangent [[attribute(4)]];
};

struct InstanceData {
    float4x4 instance_mm;
};

struct VertexOutput {
    float4 position [[position]];
    float2 tcord;
    float3 objSpacePos;
};

struct ShadowUniforms {
    float4x4 LightProjection;
    float4x4 u_View;
    float4x4 u_Projection;
    float4x4 u_Model;
    float3 u_cameraPos;
    float u_Time;
    float4 m_color;
};

// Helper Functions
float4x4 CreateRotationMat(float x, float y, float z)
{
    x = x * DEG2RAD;
    y = y * DEG2RAD;
    z = z * DEG2RAD;

    float4x4 aroundX = float4x4(
        float4(1,0,0,0),
        float4(0,cos(x),sin(x),0),
        float4(0,-sin(x),cos(x),0),
        float4(0,0,0,1));

    float4x4 aroundY = float4x4(
        float4(cos(y),0,-sin(y),0),
        float4(0,1,0,0),
        float4(sin(y),0,cos(y),0),
        float4(0,0,0,1));

    float4x4 aroundZ = float4x4(
        float4(cos(z),sin(z),0,0),
        float4(-sin(z),cos(z),0,0),
        float4(0,0,1,0),
        float4(0,0,0,1));

    return aroundX * aroundY * aroundZ;
}

float4x4 CreateScaleMatrix(float scale)
{
    return float4x4(
        float4(scale,0,0,0),
        float4(0,scale,0,0),
        float4(0,0,scale,0),
        float4(0,0,0,1)
    );
}

// Hashing Functions
float hash(float2 val)
{
    return fract(1.0e4 * sin(17.0 * val.x + 0.1 * val.y) * (0.1 + abs(sin(13.0 * val.y + val.x))));
}

float hash3D(float3 val)
{
    return hash(float2(hash(val.xy), val.z));
}

float HashedAlphaThreshold(float3 objSpacePos, float scale)
{
    float maxDeriv = max(length(dfdx(objSpacePos)), length(dfdy(objSpacePos)));
    float pixScale = 1.0 / (scale * maxDeriv);

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

    return clamp(alpha_f, 1.0e-6, 1.0);
}

// -------------------------------------------------------------------------
// VERTEX SHADER
// -------------------------------------------------------------------------
vertex VertexOutput vertex_main(VertexInput in                  [[stage_in]],
                                constant InstanceData* instances [[buffer(2)]], 
                                constant ShadowUniforms& u       [[buffer(1)]],
                                uint instanceID                  [[instance_id]])
{
    VertexOutput out;
    
    // Get Per-Instance Matrix
    float4x4 instance_mm = instances[instanceID].instance_mm;

    // Calculate Position
    float4 wsGrass = u.u_Model * instance_mm * in.pos;
    
    out.objSpacePos = wsGrass.xyz / wsGrass.w;
    out.position = u.LightProjection * wsGrass;
    out.tcord = in.cord;
    
    return out;
}

// -------------------------------------------------------------------------
// FRAGMENT SHADER
// -------------------------------------------------------------------------
fragment void fragment_main(VertexOutput in [[stage_in]],
                            texture2d<float> u_Albedo [[texture(0)]],
                            sampler sam [[sampler(0)]])
{
    float4 albedo = u_Albedo.sample(sam, in.tcord);
    
    // Standard Alpha Discard
    if(albedo.a < 0.5) discard_fragment();

    // Hashed Alpha (Optional: Uncomment to use instead of standard)
    // float threshold = HashedAlphaThreshold(in.objSpacePos, 1.0);
    // if (albedo.a < threshold) discard_fragment();
}