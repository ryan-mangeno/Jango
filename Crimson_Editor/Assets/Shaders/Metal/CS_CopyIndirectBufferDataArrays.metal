#include <metal_stdlib>
using namespace metal;

// Structure matching MTLDrawPrimitivesIndirectArguments
struct IndirectDrawArguments {
    uint vertexCount;
    uint instanceCount;
    uint vertexStart;
    uint baseInstance;
};

struct LodCountBuffer {
    int u_lodCount;
};

struct Uniforms {
    int u_vertexBufferSize;
};

// 1 thread per dispatch, matching local_size_x = 1
kernel void compute_main(device IndirectDrawArguments* indirectBuffer [[buffer(0)]],
                         constant LodCountBuffer* lodCount            [[buffer(1)]],
                         constant Uniforms& u                         [[buffer(2)]],
                         uint id                                      [[thread_position_in_grid]])
{
    // Write the draw arguments for the indirect command
    indirectBuffer[0].vertexCount = u.u_vertexBufferSize;
    indirectBuffer[0].instanceCount = lodCount[0].u_lodCount;
    
    // Note: vertexStart and baseInstance are left untouched, matching the GLSL behavior.
    // If this buffer is not cleared beforehand in C++, you might want to initialize them here:
    // indirectBuffer[0].vertexStart = 0;
    // indirectBuffer[0].baseInstance = 0;
}