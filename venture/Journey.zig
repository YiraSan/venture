const std = @import("std");
const venture = @import("venture");
const wgpu = @import("wgpu");

const Journey = @This();
allocator: std.mem.Allocator,
wgpu_instance: wgpu.WGPUInstance,

pub fn create(allocator: std.mem.Allocator) !*Journey {
    const journey = try allocator.create(Journey);
    journey.allocator = allocator;

    journey.wgpu_instance = wgpu.wgpuCreateInstance(null);

    return journey;
}

pub inline fn createView(self: *Journey, options: venture.View.ViewOptions) !*venture.View {
    return venture.View.create(self, options);
}

pub inline fn createScene(self: *Journey) !*venture.Scene {
    return venture.Scene.create(self);
}

pub fn destroy(self: *Journey) void {
    wgpu.wgpuInstanceRelease(self.wgpu_instance);
    self.allocator.destroy(self);
}
