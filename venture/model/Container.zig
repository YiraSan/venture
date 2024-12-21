const std = @import("std");
const venture = @import("venture");
const sdl = @import("sdl");

const Container = @This();
model: *venture.model.Model,
scene: *venture.render.Scene,

instances: Instances,
raw_instances: RawInstances,
remap_instances: bool,

instance_buffer: ?*sdl.SDL_GPUBuffer,
instance_buffer_capacity: usize,

const Instances = std.ArrayListUnmanaged(*venture.model.Instance);
const RawInstances = std.ArrayListUnmanaged(venture.model.Instance.Raw);

pub fn create(model: *venture.model.Model, scene: *venture.render.Scene) !*Container {
    const container = try scene.journey.allocator.create(Container);
    container.model = model;
    container.scene = scene;

    container.instances = try Instances.initCapacity(container.scene.journey.allocator, 64);
    container.raw_instances = try RawInstances.initCapacity(container.scene.journey.allocator, 64);
    container.remap_instances = false;

    container.instance_buffer = sdl.SDL_CreateGPUBuffer(
        container.scene.journey.gpu_device,
        @ptrCast(&sdl.SDL_GPUBufferCreateInfo {
            .usage = sdl.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
            .size = @sizeOf(venture.model.Instance.Raw) * 64,
        })
    );
    container.instance_buffer_capacity = 64;

    try container.scene.containers.append(container.scene.journey.allocator, container);

    return container;
}

pub fn __remap(self: *Container, copy_pass: ?*sdl.SDL_GPUCopyPass) !void {
    if (self.remap_instances) {
        self.remap_instances = false;


    }
    _ = copy_pass;
}

pub fn __render(self: *Container, render_pass: ?*sdl.SDL_GPURenderPass) !void {
    try self.model.__setup(render_pass);

    sdl.SDL_DrawGPUIndexedPrimitives(
        render_pass,
        @intCast(self.model.mesh.indices.len),
        @intCast(self.instances.items.len),
        0,
        0,
        0
    );
}

pub fn destroy(self: *Container) void {
    self.instances.deinit(self.scene.journey.allocator);
    self.raw_instances.deinit(self.scene.journey.allocator);
    self.scene.journey.allocator.destroy(self);
}

// shortcuts

pub fn createInstance(self: *Container) !*venture.model.Instance {
    return try venture.model.Instance.create(self);
}
