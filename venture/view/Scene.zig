const std = @import("std");
const venture = @import("venture");
const wgpu = @import("wgpu");

const Scene = @This();
journey: *venture.Journey,

pub fn __render_scene(
    scene: *Scene, 
    view: *venture.View, 
    render_pass_encoder: wgpu.WGPURenderPassEncoder,
) !void {
    _ = scene;
    _ = view;
    _ = render_pass_encoder;
}

pub fn create(journey: *venture.Journey) !*Scene {
    const scene = try journey.allocator.create(Scene);
    scene.journey = journey;

    return scene;
}

pub fn destroy(self: *Scene) void {
    self.journey.allocator.destroy(self);
}
