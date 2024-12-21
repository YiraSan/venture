const std = @import("std");
const venture = @import("venture");

const Scene = @This();
journey: *venture.core.Journey,

pub const Options = struct {};

pub fn create(journey: *venture.core.Journey, options: Options) !*Scene {
    const scene = try journey.allocator.create(Scene);
    scene.journey = journey;

    _ = options;

    return scene;
}

pub fn destroy(self: *Scene) void {
    self.journey.allocator.destroy(self);
}
