const std = @import("std");
const venture = @import("venture");
const wgpu = @import("wgpu");

pub const Camera = @import("Camera.zig");

const Scene = @This();
journey: *venture.Journey,
containers: std.ArrayListUnmanaged(*venture.Model.Container),
containers_lock: std.Thread.RwLock,

pub fn __render_scene(
    scene: *Scene,
    render_pass_encoder: wgpu.WGPURenderPassEncoder,
) !void {
    scene.containers_lock.lockShared();
    defer scene.containers_lock.unlockShared();
    for (scene.containers.items) |container| {
        if (container.scene == scene) {
            try container.__render(render_pass_encoder);
        }
    }
}

pub const Options = struct {

};

pub fn create(journey: *venture.Journey, options: Options) !*Scene {
    const scene = try journey.allocator.create(Scene);
    scene.journey = journey;
    scene.containers = try std.ArrayListUnmanaged(*venture.Model.Container).initCapacity(scene.journey.allocator, 64);
    scene.containers_lock = .{};

    _ = options;

    return scene;
}

pub fn destroy(self: *Scene) void {
    {
        for (self.containers.items) |container| {
            {
                container.model.containers_lock.lock();
                defer container.model.containers_lock.unlock();

                for (0.., container.model.containers.items) |i, con| {
                    if (con == container) {
                        _ = container.model.containers.swapRemove(i);
                        break;
                    }
                }
            }
            container._destroy();
        }
        self.containers.deinit(self.journey.allocator);
    }
    self.journey.allocator.destroy(self);
}
