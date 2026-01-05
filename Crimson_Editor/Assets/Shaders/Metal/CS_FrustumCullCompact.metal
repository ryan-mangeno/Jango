#include <metal_stdlib>
using namespace metal;

struct ScanUniforms {
    int offset;
};

kernel void compute_main(device float4x4* inBuffer     [[buffer(0)]],
                         device int* voteBuffer        [[buffer(1)]],
                         device int* scanBuffer        [[buffer(2)]],
                         device float4x4* outBuffer    [[buffer(3)]],
                         constant ScanUniforms& u      [[buffer(4)]],
                         uint id                       [[thread_position_in_grid]])
{
    uint index = id + u.offset;

    if (voteBuffer[index] == 1)
    {
        int outIndex = scanBuffer[index];
        outBuffer[outIndex] = inBuffer[index];
    }
}