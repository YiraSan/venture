const std = @import("std");
const venture = @import("venture");
const sdl = @import("sdl");
const zmath = @import("zmath");

const Instance = @This();
container: *venture.model.Container,
index: usize,

coordinate: @Vector(3, f32),
rotation: @Vector(3, f32),

pub fn create(container: *venture.model.Container) !*Instance {
    const instance = try container.scene.journey.allocator.create(Instance);
    instance.container = container;
    instance.index = container.instances.items.len;

    instance.coordinate = .{ 0.0, 0.0, 0.0 };
    instance.rotation = .{ 0.0, 0.0, 0.0 };

    try container.instances.append(instance.container.scene.journey.allocator, instance);
    try container.raw_instances.append(instance.container.scene.journey.allocator, Raw { .model = zmath.identity() });

    container.remap_instances = true;

    return instance;
}

pub fn update(self: *Instance) void {
    const rotation_matrix = zmath.quatToMat(zmath.quatFromRollPitchYaw(
        self.rotation[0], self.rotation[1], self.rotation[2]
    ));

    const translation_matrix = zmath.translation(
        self.coordinate[0], self.coordinate[1], self.coordinate[2]);

    self.container.raw_instances.items[self.index] = .{ 
        .model = zmath.mul(rotation_matrix, translation_matrix),
    };
    self.container.remap_instances = true;
}

pub fn setCoordinate(self: *Instance, x: ?f32, y: ?f32, z: ?f32) void {
    if (x) |c| self.coordinate[0] = c;
    if (y) |c| self.coordinate[1] = c;
    if (z) |c| self.coordinate[2] = c;
}

pub fn setRotation(self: *Instance, x: ?f32, y: ?f32, z: ?f32) void {
    if (x) |c| self.rotation[0] = c;
    if (y) |c| self.rotation[1] = c;
    if (z) |c| self.rotation[2] = c;
}

pub fn destroy(self: *Instance) void {
    const instances = &self.container.instances;
    const raw_instances = &self.container.raw_instances;

    const i = self.index;

    if (instances.items.len - 1 == i) {
        _ = instances.pop();
        _ = raw_instances.pop();
    } else {
        instances.items[i] = instances.pop();
        instances.items[i].index = i;
        raw_instances.items[i] = raw_instances.pop();
        self.container.remap_instances = true;
    }

    self.container.scene.journey.allocator.destroy(self);
}

pub const Raw = struct {
    model: zmath.Mat
};
