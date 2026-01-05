#include <metal_stdlib>
using namespace metal;

struct CullingUniforms {
    float3 camPos;
    float pad;
    float4x4 u_ViewProjection;
    float u_cullDistance;
    float3 aabb_min;
    float3 aabb_max;
};

struct InstanceCount {
    uint instanceCount;
};

bool within(float left, float point, float right)
{
    return (point >= left) && (point <= right);
}

kernel void compute_main(device float4x4* inBuffer              [[buffer(0)]],
                         constant InstanceCount* totalInstCount [[buffer(1)]],
                         device float4x4* outBuffer             [[buffer(2)]],
                         device atomic_uint* totalInstances     [[buffer(3)]],
                         constant CullingUniforms& u            [[buffer(4)]],
                         uint index                             [[thread_position_in_grid]])
{
    if (index == 0) {
        atomic_store_explicit(totalInstances, 0, memory_order_relaxed);
    }

    if (index >= totalInstCount->instanceCount) {
        return;
    }

    float4x4 instance_matrix = inBuffer[index];
    float3 foliage_pos = float3(instance_matrix[3][0], instance_matrix[3][1], instance_matrix[3][2]);

    float4 corners[8];
    corners[0] = float4(u.aabb_min.x, u.aabb_min.y, u.aabb_min.z, 1.0);
    corners[1] = float4(u.aabb_max.x, u.aabb_min.y, u.aabb_min.z, 1.0);
    corners[2] = float4(u.aabb_min.x, u.aabb_max.y, u.aabb_min.z, 1.0);
    corners[3] = float4(u.aabb_max.x, u.aabb_max.y, u.aabb_min.z, 1.0);
    corners[4] = float4(u.aabb_min.x, u.aabb_min.y, u.aabb_max.z, 1.0);
    corners[5] = float4(u.aabb_max.x, u.aabb_min.y, u.aabb_max.z, 1.0);
    corners[6] = float4(u.aabb_min.x, u.aabb_max.y, u.aabb_max.z, 1.0);
    corners[7] = float4(u.aabb_max.x, u.aabb_max.y, u.aabb_max.z, 1.0);

    bool inview = false;
    for (int i = 0; i < 8; i++)
    {
        float4 clipSpace = u.u_ViewProjection * instance_matrix * corners[i];
        
        bool inside = within(-clipSpace.w, clipSpace.x, clipSpace.w) && 
                      within(-clipSpace.w, clipSpace.y, clipSpace.w) && 
                      within(-clipSpace.w, clipSpace.z, clipSpace.w);
                      
        inview = inview || inside;
        
        if (inview) break; 
    }

    if (inview && distance(foliage_pos, u.camPos) <= u.u_cullDistance)
    {
        uint count = atomic_fetch_add_explicit(totalInstances, 1, memory_order_relaxed);
        outBuffer[count] = instance_matrix;
    }
}