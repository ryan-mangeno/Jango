#include <metal_stdlib>
using namespace metal;

struct PlacementUniforms {
    int u_instanceCount;
    int u_nearestDistance;
    int u_alignToTerrainNormal;
    float u_HeightMapScale;
    float u_zoi;
    float u_trunk_radius;
    float u_predominanceValue;
    float u_minScale;
    float u_maxScale;
};

struct RandomState {
    uint4 seed;
};

void pcg4d(thread uint4& v)
{
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.w; v.y += v.z * v.x; v.z += v.x * v.y; v.w += v.y * v.z;
    v = v ^ (v >> 16u);
    v.x += v.y * v.w; v.y += v.z * v.x; v.z += v.x * v.y; v.w += v.y * v.z;
}

float random(thread RandomState& rng)
{
    pcg4d(rng.seed);
    return float(rng.seed.x) / float(0xffffffffu);
}

float randomInRange(thread RandomState& rng, float _min, float _max)
{
    return random(rng) * (_max - _min) + _min;
}

float4x4 CreateTranslationMatrix(float3 pos)
{
    return float4x4(float4(1,0,0,0),
                    float4(0,1,0,0),
                    float4(0,0,1,0),
                    float4(pos.x, pos.y, pos.z, 1));
}

float4x4 CreateRotationMatrix(float3 rotation)
{
    float4x4 aroundX = float4x4(float4(1,0,0,0),
                                float4(0,cos(rotation.x),sin(rotation.x),0),
                                float4(0,-sin(rotation.x),cos(rotation.x),0),
                                float4(0,0,0,1));

    float4x4 aroundY = float4x4(float4(cos(rotation.y),0,-sin(rotation.y),0),
                                float4(0,1,0,0),
                                float4(sin(rotation.y),0,cos(rotation.y),0),
                                float4(0,0,0,1));

    float4x4 aroundZ = float4x4(float4(cos(rotation.z),sin(rotation.z),0,0),
                                float4(-sin(rotation.z),cos(rotation.z),0,0),
                                float4(0,0,1,0),
                                float4(0,0,0,1));

    return aroundZ * aroundY * aroundX;
}

float4x4 CreateScaleMatrix(float scale)
{
    return float4x4(float4(scale,0,0,0),
                    float4(0,scale,0,0),
                    float4(0,0,scale,0),
                    float4(0,0,0,1));
}

float3 TerrainNormal(texture2d<float> heightMap, sampler s, float heightScale, float2 texCoord, float2 texelSize)
{
    float left  = heightMap.sample(s, texCoord + float2(-texelSize.x, 0.0), level(0)).r * heightScale * 2.0 - heightScale;
    float right = heightMap.sample(s, texCoord + float2( texelSize.x, 0.0), level(0)).r * heightScale * 2.0 - heightScale;
    float up    = heightMap.sample(s, texCoord + float2(0.0,  texelSize.y), level(0)).r * heightScale * 2.0 - heightScale;
    float down  = heightMap.sample(s, texCoord + float2(0.0, -texelSize.y), level(0)).r * heightScale * 2.0 - heightScale;

    return normalize(float3(left - right, 2.0, down - up));
}

float CalculateSlope(float3 normal)
{
    return 1.0 - normal.y;
}

void CreateDensity(texture2d<float, access::read_write> densityMap, int2 coord, int dist, float trunk_radius, float zoi)
{
    for(int i = -dist; i <= dist; i++)
    {
        for(int j = -dist; j <= dist; j++)
        {
            int2 neighborCoord = coord + int2(i, j);
            
            // bounds check for safety in compute
            if (neighborCoord.x < 0 || neighborCoord.y < 0 || 
                neighborCoord.x >= int(densityMap.get_width()) || 
                neighborCoord.y >= int(densityMap.get_height())) continue;

            float d = distance(float2(coord), float2(neighborCoord));
            float distanceField = 1.0 - clamp((d - trunk_radius) / (zoi - trunk_radius), 0.0, 1.0);
            
            float3 color = densityMap.read(uint2(neighborCoord)).rgb;
            float3 combined = clamp(float3(distanceField) + color, 0.0, 1.0);
            
            densityMap.write(float4(combined, 1.0), uint2(neighborCoord));
        }
    }
}

kernel void compute_main(device float4x4* inBuffer                [[buffer(0)]],
                         device float2* posBuffer                 [[buffer(1)]],
                         device atomic_uint* Count_Instances      [[buffer(2)]],
                         texture2d<float, access::read_write> densityMap [[texture(0)]],
                         texture2d<float> u_DensityMap            [[texture(1)]],
                         texture2d<float> u_HeightMap             [[texture(2)]],
                         constant PlacementUniforms& u            [[buffer(3)]],
                         sampler sam                              [[sampler(0)]],
                         uint id                                  [[thread_position_in_grid]])
{
    int m_index = int(id);

    if (m_index < u.u_instanceCount)
    {
        float P = 1.0;
        
        float2 foliagePos = posBuffer[m_index];
        
        RandomState rng;
        rng.seed = uint4(uint(foliagePos.x), 5, uint(foliagePos.y), 1);

        float3 jitter_pos = float3(foliagePos.x + randomInRange(rng, 1.0, 5.0), 
                                   0.0, 
                                   foliagePos.y + randomInRange(rng, 1.0, 5.0));

        float2 texelSize = 1.0 / float2(u_HeightMap.get_width(), u_HeightMap.get_height());
        float2 uv = jitter_pos.xz * texelSize; 
        
        float height = u_HeightMap.sample(sam, uv, level(0)).r * u.u_HeightMapScale;
        
        float3 terrainNormal = TerrainNormal(u_HeightMap, sam, u.u_HeightMapScale, uv, texelSize); 
        float slope = CalculateSlope(terrainNormal); 
        slope = clamp((slope - 0.5) * 10.0 + 0.5, 0.0, 1.0); 
        
        jitter_pos.y = height; 

        P = P * (1.0 - slope); 
        P = P * u.u_predominanceValue;
        P = P * u_DensityMap.sample(sam, uv, level(0)).x;
        
        // load current density state from read_write texture
        // warning: race condition possible if multiple threads modify same neighborhood
        float densityVal = densityMap.read(uint2(jitter_pos.xz)).r;
        P = P * (1.0 - densityVal); 

        float3 rotationAxis = float3(0);
        float rotationAngle = 0;

        if (random(rng) < P)
        {
            uint index = atomic_fetch_add_explicit(Count_Instances, 1, memory_order_relaxed); 
            
            if (u.u_alignToTerrainNormal == 1)
            {
                rotationAxis = -cross(float3(0, 1.0, 0), terrainNormal); 
                rotationAngle = acos(dot(float3(0, 1.0, 0), terrainNormal)); 
            }

            float4x4 rotMat = CreateRotationMatrix(rotationAngle * rotationAxis);
            float4x4 randRotMat = CreateRotationMatrix(float3(0, randomInRange(rng, -80, 70), 0));
            float4x4 scaleMat = CreateScaleMatrix(randomInRange(rng, max(u.u_minScale, 1.0), max(u.u_maxScale, 2.0)));
            float4x4 transMat = CreateTranslationMatrix(jitter_pos);

            inBuffer[index] = transMat * rotMat * randRotMat * scaleMat;
            
            CreateDensity(densityMap, int2(jitter_pos.xz), u.u_nearestDistance, u.u_trunk_radius, u.u_zoi);
        }
    }   
}