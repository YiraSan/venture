const std = @import("std");
const venture = @import("venture");
const sdl = @import("sdl");
const zmath = @import("zmath");

const Instance = @This();
container: *venture.model.Container,
index: usize,

pub fn create(container: *venture.model.Container) !*Instance {
    const instance = try container.scene.journey.allocator.create(Instance);
    instance.container = container;
    instance.index = container.instances.items.len;

    try container.instances.append(instance.container.scene.journey.allocator, instance);

    return instance;
}

pub fn destroy(self: *Instance) void {
    self.container.scene.journey.allocator.destroy(self);
}

pub const Raw = extern struct {
    view_projection: zmath.Mat,
};
