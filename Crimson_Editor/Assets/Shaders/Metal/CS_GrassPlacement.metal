#include <metal_stdlib>
using namespace metal;

constant float DEG2RAD = 0.01745329251f;

struct FoliageUniforms {
    float3 u_PlayerPos;
    float u_HeightMapScale;
    float u_instanceCount;
    float u_spacing;
};

void pcg4d(thread uint4& v)
{
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.w; v.y += v.z * v.x; v.z += v.x * v.y; v.w += v.y * v.z;
    v = v ^ (v >> 16u);
    v.x += v.y * v.w; v.y += v.z * v.x; v.z += v.x * v.y; v.w += v.y * v.z;
}

float random(thread uint4& seed)
{
    pcg4d(seed);
    return float(seed.x) / float(0xffffffffu);
}

float randomInRange(thread uint4& seed, float _min, float _max)
{
    return random(seed) * (_max - _min) + _min;
}

float4x4 CreateTranslationMatrix(float3 pos)
{
    return float4x4(float4(1,0,0,0),
                    float4(0,1,0,0),
                    float4(0,0,1,0),
                    float4(pos.x, pos.y, pos.z, 1));
}

float4x4 CreateRotationMatrix(float x, float y, float z)
{
    x = x * DEG2RAD;
    y = y * DEG2RAD;
    z = z * DEG2RAD;

    float4x4 aroundX = float4x4(float4(1,0,0,0),
                                float4(0,cos(x),sin(x),0),
                                float4(0,-sin(x),cos(x),0),
                                float4(0,0,0,1));

    float4x4 aroundY = float4x4(float4(cos(y),0,-sin(y),0),
                                float4(0,1,0,0),
                                float4(sin(y),0,cos(y),0),
                                float4(0,0,0,1));

    float4x4 aroundZ = float4x4(float4(cos(z),sin(z),0,0),
                                float4(-sin(z),cos(z),0,0),
                                float4(0,0,1,0),
                                float4(0,0,0,1));

    return aroundX * aroundY * aroundZ;
}

float4x4 CreateScaleMatrix(float scale)
{
    return float4x4(float4(scale,0,0,0),
                    float4(0,scale,0,0),
                    float4(0,0,scale,0),
                    float4(0,0,0,1));
}

float3 CalculateNormal(texture2d<float> heightMap, sampler s, float heightScale, float2 texCoord, float2 texelSize)
{
    float left  = heightMap.sample(s, texCoord + float2(-texelSize.x, 0.0), level(0)).r * heightScale * 2.0 - heightScale;
    float right = heightMap.sample(s, texCoord + float2( texelSize.x, 0.0), level(0)).r * heightScale * 2.0 - heightScale;
    float up    = heightMap.sample(s, texCoord + float2(0.0,  texelSize.y), level(0)).r * heightScale * 2.0 - heightScale;
    float down  = heightMap.sample(s, texCoord + float2(0.0, -texelSize.y), level(0)).r * heightScale * 2.0 - heightScale;

    return normalize(float3(down - up, 2.0, left - right));
}

kernel void compute_main(device float4x4* outMatrices             [[buffer(0)]],
                         device atomic_uint* counter_instances    [[buffer(1)]],
                         constant FoliageUniforms& u              [[buffer(2)]],
                         texture2d<float> u_DensityMap            [[texture(0)]],
                         texture2d<float> u_HeightMap             [[texture(1)]],
                         sampler sam                              [[sampler(0)]],
                         uint2 gid                                [[thread_position_in_grid]],
                         uint2 gridSize                           [[threads_per_grid]])
{
    int m_index = int(gid.y * gridSize.x + gid.x);

    // reset counter on first thread strictly for glsl compatibility
    // race condition warning: prefer clearing buffer via cpu command
    if (m_index == 0)
    {
        atomic_store_explicit(counter_instances, 0, memory_order_relaxed);
    }

    float2 foliagePos = float2(gid.x, gid.y) * u.u_spacing;
    
    // match glsl offset logic based on grid dimensions
    float2 gridOffset = float2(gridSize.x / 2.0, gridSize.y / 2.0); 
    
    float2 offsetPos = foliagePos + u.u_PlayerPos.xz - gridOffset;
    foliagePos = max(offsetPos, foliagePos);

    float2 texelSize = float2(1.0) / float2(u_HeightMap.get_width(), u_HeightMap.get_height());
    float2 uv = foliagePos * texelSize; 
    
    // explicit level 0 required for compute sampling
    float height = u_HeightMap.sample(sam, uv, level(0)).r * u.u_HeightMapScale;

    uint4 seed = uint4(uint(foliagePos.x), uint(height), uint(foliagePos.y), uint(m_index));

    float3 pos = float3(foliagePos.x + randomInRange(seed, 1.0, 5.0), 
                        height, 
                        foliagePos.y + randomInRange(seed, 1.0, 5.0));

    float3 normal = CalculateNormal(u_HeightMap, sam, u.u_HeightMapScale, uv, texelSize);
    
    // push position along normal if terrain is steep
    if ((1.0 - normal.y) > 0.4)
    {
        pos = pos + normal * 2.0;
    }

    float densitySample = u_DensityMap.sample(sam, pos.xz / 2048.0, level(0)).r;
    
    if (random(seed) < densitySample)
    {
        uint index = atomic_fetch_add_explicit(counter_instances, 1, memory_order_relaxed);
        
        float4x4 mat = CreateTranslationMatrix(pos) * CreateRotationMatrix(randomInRange(seed, 0.0, 5.0), 
                                            randomInRange(seed, 5.0, 10.0), 
                                            randomInRange(seed, 0.0, 5.0)) * CreateScaleMatrix(randomInRange(seed, 1.0, 2.0));
                       
        outMatrices[m_index] = mat;
    }
}