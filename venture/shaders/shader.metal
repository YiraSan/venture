#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct vs_main_out {
    float4 position [[position]];
    float4 color;
};

struct vs_main_in
{
    float4 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct vs_instance
{
    float4x4 model_matrix;
};

struct camera_uniform
{
    float4x4 view_projection;
};

vertex vs_main_out vs_main(
    vs_main_in in [[stage_in]], 
    const device camera_uniform &camera [[buffer(0)]],
    const device vs_instance *instances [[buffer(1)]],
    uint instance_id [[instance_id]]
) {
    vs_main_out payload;
    payload.position = camera.view_projection * instances[instance_id].model_matrix * in.position;
    payload.color = in.color;
    return payload;
}

float4 fragment fs_main(vs_main_out interpolated [[stage_in]]) {
    return interpolated.color;
}
