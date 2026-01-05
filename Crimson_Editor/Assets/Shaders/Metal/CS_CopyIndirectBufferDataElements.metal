#include <metal_stdlib>
using namespace metal;

// Structure matching MTLDrawIndexedPrimitivesIndirectArguments
struct IndirectDrawIndexedArguments {
    uint indexCount;
    uint instanceCount;
    uint indexStart;
    int  baseVertex;
    uint baseInstance;
};

struct LodCountBuffer {
    int lodCount;
};

struct Uniforms {
    int IndexBufferSize;
};

kernel void compute_main(device IndirectDrawIndexedArguments* indirectBuffer [[buffer(0)]],
                         constant LodCountBuffer* lodCount            [[buffer(1)]],
                         constant Uniforms& u                         [[buffer(2)]],
                         uint id                                      [[thread_position_in_grid]])
{
    // Write arguments for an indexed indirect draw
    indirectBuffer[0].indexCount    = u.IndexBufferSize;
    indirectBuffer[0].instanceCount = lodCount[0].lodCount;
    indirectBuffer[0].indexStart    = 0;
    indirectBuffer[0].baseVertex    = 0;
    indirectBuffer[0].baseInstance  = 0;
}