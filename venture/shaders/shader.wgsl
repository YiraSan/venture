struct Payload {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>,
}

@vertex
fn vs_main(
    @location(0) position: vec4<f32>,
    @location(1) color: vec4<f32>
) -> Payload {
    var output: Payload;
    output.position = position;
    output.color = color;
    return output;
}

@fragment
fn fs_main(payload: Payload) -> @location(0) vec4<f32> {
    return payload.color;
}
