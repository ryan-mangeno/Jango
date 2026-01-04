#include <metal_stdlib>
using namespace metal;

// -------------------------------------------------------------------------
// CONSTANTS
// -------------------------------------------------------------------------
#define RANDOM_SAMPLES_SIZE 64

struct VertexInput {
    float4 position [[attribute(0)]];
    float4 cord     [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 tcord;
};

// -------------------------------------------------------------------------
// UNIFORMS
// -------------------------------------------------------------------------
struct SSAOUniforms {
    float ScreenWidth;
    float ScreenHeight;
    
    // Arrays in Metal Constant buffers are 16-byte aligned
    // Ensure C++ sends glm::vec4s here
    float4 Samples[RANDOM_SAMPLES_SIZE]; 
    
    float4x4 u_projection;
    
    // Calculated in C++ (glm::inverse(u_projection))
    float4x4 u_InverseProjection; 
    
    float3 u_CamPos;
    int isFoliage;
};

// -------------------------------------------------------------------------
// HELPER FUNCTIONS
// -------------------------------------------------------------------------

// Reconstruct View Space Position from Depth
float3 GetViewSpacePosition(float2 uv, texture2d<float> depthTex, sampler sam, float4x4 invProj) 
{
    float z = depthTex.sample(sam, uv).r;
    
    // Convert 0..1 UV and 0..1 Depth to Clip Space (-1..1)
    // If switched to Metal's 0..1 Depth, change z*2.0-1.0 to just z
    // Keeping GLSL logic for compatibility:
    float4 clip_space = float4(uv * 2.0 - 1.0, z * 2.0 - 1.0, 1.0);
    
    float4 view_space = invProj * clip_space;
    view_space /= view_space.w;
    
    return view_space.xyz;
}

// -------------------------------------------------------------------------
// VERTEX SHADER
// -------------------------------------------------------------------------
vertex VertexOutput vertex_main(VertexInput in [[stage_in]])
{
    VertexOutput out;
    out.position = in.position;
    out.tcord = in.cord.xy;
    return out;
}

// -------------------------------------------------------------------------
// FRAGMENT SHADER
// -------------------------------------------------------------------------
fragment float4 fragment_main(VertexOutput in [[stage_in]],
                              constant SSAOUniforms& u [[buffer(1)]],
                              
                              texture2d<float> depthBuffer [[texture(0)]],
                              texture2d<float> gNormal     [[texture(1)]],
                              texture2d<float> noisetex    [[texture(2)]],
                              
                              // Foliage array (Unused in logic but present in binding)
                              texture2d_array<float> alpha_texture [[texture(3)]],
                              
                              sampler sam [[sampler(0)]])
{
    // Define a repeating sampler specifically for the noise texture
    constexpr sampler noiseSampler(address::repeat, filter::nearest);

    float radius = 0.4;
    float bias = 0.085;
    
    float2 noiseScale = float2(u.ScreenWidth / 4.0, u.ScreenHeight / 4.0);
    
    // Get Geometry Data
    float3 FragPos = GetViewSpacePosition(in.tcord, depthBuffer, sam, u.u_InverseProjection);
    float3 Normal = normalize(gNormal.sample(sam, in.tcord).xyz);
    float3 RandomVec = noisetex.sample(noiseSampler, in.tcord * noiseScale).xyz;
    
    // Create TBN Matrix (Tangent-Bitangent-Normal)
    // Gram-Schmidt process to orthogonalize
    float3 tangent = normalize(RandomVec - Normal * dot(RandomVec, Normal));
    float3 bitangent = cross(Normal, tangent);
    float3x3 TBN = float3x3(tangent, bitangent, Normal);
    
    float occlusion = 0.0;
    
    // Iterate Samples
    for(int i = 0; i < RANDOM_SAMPLES_SIZE; i++)
    {
        // Get sample position
        float3 samplePos = TBN * u.Samples[i].xyz; // From tangent to view-space
        samplePos = FragPos + samplePos * radius; 
        
        // Project sample position (to texture coord)
        float4 offset = float4(samplePos, 1.0);
        offset = u.u_projection * offset;
        offset.xyz /= offset.w; // Perspective divide
        offset.xyz = offset.xyz * 0.5 + 0.5; // Transform to 0.0 - 1.0 range
        
        // Get depth of the sample position
        // Note: Using standard sampler for depth lookup
        float3 depthPos = GetViewSpacePosition(offset.xy, depthBuffer, sam, u.u_InverseProjection);
        float sampleDepth = depthPos.z;
        
        // Range Check (prevents haloing around objects)
        float rangeCheck = smoothstep(0.0, 1.0, radius / abs(FragPos.z - sampleDepth));
        
        // Accumulate Occlusion
        // Check if sample depth is "closer" to camera than the generated samplePos
        // (In View Space, Z is negative looking forward usually, check coordinate system!)
        // Based on GLSL: "depth.z >= SamplePoint.z + bias" implies Z decreases away from camera (Right Handed)?
        // Adjust condition if Z is positive. Assuming GLSL logic holds:
        occlusion += (sampleDepth >= samplePos.z + bias ? 1.0 : 0.0) * rangeCheck;
    }
    
    occlusion = 1.0 - (occlusion / float(RANDOM_SAMPLES_SIZE));
    
    // Output squared result for stronger effect
    return float4(pow(occlusion, 2.0));
}