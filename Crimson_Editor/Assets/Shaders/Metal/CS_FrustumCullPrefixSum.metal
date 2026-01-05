#include <metal_stdlib>
using namespace metal;

struct ScanUniforms {
    int stride;
};

// Use atomic_int for the total sum to ensure memory safety between groups,
// though the algorithm implies serial dependency or single-dispatch logic.
struct TotalSumBuffer {
    atomic_int TotSum;
};

kernel void compute_main(device int* inBuffer              [[buffer(0)]],
                         device int* sumBuffer             [[buffer(1)]],
                         device TotalSumBuffer* totalSum   [[buffer(2)]],
                         constant ScanUniforms& u          [[buffer(3)]],
                         uint lid                          [[thread_position_in_threadgroup]],
                         uint gid                          [[thread_position_in_grid]])
{
    // Shared memory for the block (2 elements per thread * 512 threads = 1024)
    threadgroup int tmp[1024];

    // Reset total sum if this is the first pass (stride == 0)
    // We check gid == 0 to ensure only one thread does this write.
    if (gid == 0 && u.stride == 0)
    {
        atomic_store_explicit(&totalSum->TotSum, 0, memory_order_relaxed);
    }
    
    // Ensure the clear is visible before proceeding (if relying on global memory consistency)
    threadgroup_barrier(mem_flags::mem_device);

    // Load Data into Shared Memory
    // We use the global ID + stride for input buffer access,
    // but the local ID (lid) for shared memory indexing to stay within [0, 1023]
    int inputIdx1 = 2 * (gid + u.stride);
    int inputIdx2 = 2 * (gid + u.stride) + 1;

    tmp[2 * lid]     = inBuffer[inputIdx1];
    tmp[2 * lid + 1] = inBuffer[inputIdx2];

    threadgroup_barrier(mem_flags::mem_threadgroup);

    int num_elements = 1024;
    int offset = 1;

    // Up-Sweep (Parallel Reduction)
    for (int d = num_elements >> 1; d > 0; d >>= 1)
    {
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        if (lid < uint(d))
        {
            int ai = offset * (2 * lid + 1) - 1;
            int bi = offset * (2 * lid + 2) - 1;
            tmp[bi] += tmp[ai];
        }
        offset <<= 1;
    }

    // Clear the last element to zero before down-sweep
    if (lid == 0)
    {
        tmp[num_elements - 1] = 0;
    }

    // Down-Sweep
    for (int d = 1; d < num_elements; d *= 2)
    {
        offset >>= 1;
        threadgroup_barrier(mem_flags::mem_threadgroup);

        if (lid < uint(d))
        {
            int ai = offset * (2 * lid + 1) - 1;
            int bi = offset * (2 * lid + 2) - 1;
            
            int t = tmp[ai];
            tmp[ai] = tmp[bi];
            tmp[bi] += t;
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Write Result to Global Memory
    // Apply the accumulated TotalSum from previous blocks
    int currentTotalSum = atomic_load_explicit(&totalSum->TotSum, memory_order_relaxed);

    sumBuffer[inputIdx1] = tmp[2 * lid] + currentTotalSum;
    sumBuffer[inputIdx2] = tmp[2 * lid + 1] + currentTotalSum;

    // Accumulate Block Sum
    // If this is the last thread in the group, add this block's contribution to the global sum
    // for the next dispatch.
    if (lid == 511)
    {
        atomic_fetch_add_explicit(&totalSum->TotSum, tmp[num_elements - 1], memory_order_relaxed);
    }
}