#include <metal_stdlib>
using namespace metal;

struct LodUniforms {
    float3 u_camPos;
    float4x4 u_ModelMat;
    // Padding required for alignment (Metal buffers prefer 16-byte alignment for float3/4/mat4 mixes)
    float _pad; 
    
    // u_VertexBufferLength0/1 unused in shader logic, but kept for struct alignment if needed
    int u_VertexBufferLength0; 
    int u_VertexBufferLength1;
    float u_LOD0Distance;
};

// Layout matching the buffers
kernel void compute_main(device float4x4* inTrans           [[buffer(0)]],
                         device float4x4* outTransLOD0      [[buffer(1)]],
                         device float4x4* outTransLOD1      [[buffer(2)]],
                         device atomic_uint* Counter_Lod0   [[buffer(3)]],
                         device atomic_uint* Counter_Lod1   [[buffer(4)]],
                         constant int* inTotalPrefixSum     [[buffer(5)]],
                         constant LodUniforms& u            [[buffer(6)]],
                         uint id                            [[thread_position_in_grid]])
{
    // Bounds Check
    // Dereference pointer for totalPrefixSum as it's a buffer
    if (id >= uint(inTotalPrefixSum[0])) return;

    // Counter Reset Logic (Matching GLSL)
    // Doing this inside the draw dispatch is risky for race conditions
    // Ideally, clear counters on CPU before dispatch
    if (id == 0)
    {
        atomic_store_explicit(Counter_Lod0, 0, memory_order_relaxed);
        atomic_store_explicit(Counter_Lod1, 0, memory_order_relaxed);
    }
    
    // Ensure thread 0s write is visible (memory barrier) if we strictly relied on it,
    // but standard GLSL->Metal ports usually assume standard flow
    // threadgroup_barrier(mem_flags::mem_device); 

    // Transform Position
    // Metal matrices are column-major. multiplication order matches GLSL: Matrix * Vector
    float4x4 instanceMat = inTrans[id];
    float4x4 worldMat = u.u_ModelMat * instanceMat;
    
    // Extract position (column 3 for standard 4x4 transformation matrices)
    float3 pos = (worldMat * float4(0, 0, 0, 1)).xyz;

    // Distance Calculation
    float dist = distance(pos, u.u_camPos);

    // Binning / Sorting
    if (dist < u.u_LOD0Distance)
    {
        // atomic_fetch_add returns the value BEFORE incrementing, which acts as our index
        uint index = atomic_fetch_add_explicit(Counter_Lod0, 1, memory_order_relaxed);
        outTransLOD0[index] = instanceMat;
    }
    else
    {
        uint index = atomic_fetch_add_explicit(Counter_Lod1, 1, memory_order_relaxed);
        outTransLOD1[index] = instanceMat;
    }
}