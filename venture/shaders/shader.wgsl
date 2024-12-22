struct Payload {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>,
}

@group(0) @binding(0)
var<uniform> view_projection: mat4x4<f32>;

@group(0) @binding(1)
var<storage, read> instances: array<mat4x4<f32>>;

@vertex
fn vs_main(
    @location(0) position: vec4<f32>,
    @location(1) color: vec4<f32>,
    @builtin(instance_index) instance_id: u32,
) -> Payload {
    var output: Payload;
    output.position = view_projection * instances[instance_id] * position;
    output.color = color;
    return output;
}

@fragment
fn fs_main(payload: Payload) -> @location(0) vec4<f32> {
    return payload.color;
}
