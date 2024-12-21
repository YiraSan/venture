const std = @import("std");
const venture = @import("venture");
const sdl = @import("sdl");

const Scene = @This();
journey: *venture.core.Journey,

containers: Containers,

const Containers = std.ArrayListUnmanaged(*venture.model.Container);

pub const Options = struct {};

pub fn create(journey: *venture.core.Journey, options: Options) !*Scene {
    const scene = try journey.allocator.create(Scene);
    scene.journey = journey;

    _ = options;

    scene.containers = try Containers.initCapacity(scene.journey.allocator, 16);

    return scene;
}

pub fn __remap(self: *Scene, copy_pass: ?*sdl.SDL_GPUCopyPass) !void {
    for (self.containers.items) |container| {
        try container.__remap(copy_pass);
    }
} 

pub fn __render(self: *Scene, render_pass: ?*sdl.SDL_GPURenderPass) !void {
    for (self.containers.items) |container| {
        try container.__render(render_pass);
    }
} 

pub fn destroy(self: *Scene) void {
    self.containers.deinit(self.journey.allocator);
    self.journey.allocator.destroy(self);
}
