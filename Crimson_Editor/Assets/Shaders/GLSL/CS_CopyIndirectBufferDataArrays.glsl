#shader compute
#version 460 core
layout (local_size_x = 1) in;

layout (std430, binding = 0) buffer u_indirectBufferLOD0
{
    unsigned int u_count;
    unsigned int u_instanceCount;
    unsigned int u_first;
    unsigned int u_baseInstance;
} outIndirectBufferLOD0;

layout (std430, binding = 1) buffer u_lodCountBuffer
{
    int u_lodCount;
} inLodCount;

uniform int u_vertexBufferSize;

void main()
{
    // Set the count and instance count based on the inputs
    outIndirectBufferLOD0.u_count = u_vertexBufferSize;
    outIndirectBufferLOD0.u_instanceCount = inLodCount.u_lodCount;
}