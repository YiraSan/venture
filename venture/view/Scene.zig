const std = @import("std");
const venture = @import("venture");
const wgpu = @import("wgpu");

const Scene = @This();
journey: *venture.Journey,

pub fn create(journey: *venture.Journey) !*Scene {
    const scene = try journey.allocator.create(Scene);
    scene.journey = journey;

    return scene;
}

pub fn __view_render(
    self: *Scene, 
    view: *venture.View, 
    render_pass_encoder: wgpu.WGPURenderPassEncoder,
) !void {
    _ = self;
    _ = view;
    _ = render_pass_encoder;
}

pub fn destroy(self: *Scene) void {
    self.journey.allocator.destroy(self);
}
