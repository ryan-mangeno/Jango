#include <metal_stdlib>
using namespace metal;

kernel void compute_main(texture2d<float, access::write> densityMap [[texture(0)]],
                         uint2 gid [[thread_position_in_grid]])
{
    densityMap.write(float4(0.0, 0.0, 0.0, 1.0), gid);
}