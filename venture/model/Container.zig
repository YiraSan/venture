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

transfer_buffer: ?*sdl.SDL_GPUTransferBuffer,

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

    container.transfer_buffer = sdl.SDL_CreateGPUTransferBuffer(
        container.scene.journey.gpu_device,
        @ptrCast(&sdl.SDL_GPUBufferCreateInfo {
            .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .size = @sizeOf(venture.model.Instance.Raw) * 64,
        })
    );

    container.instance_buffer_capacity = 64;

    try container.scene.containers.append(container.scene.journey.allocator, container);

    return container;
}

pub fn __remap(self: *Container, copy_pass: ?*sdl.SDL_GPUCopyPass) !void {
    if (self.instances.items.len == 0) return;

    if (self.remap_instances) {
        self.remap_instances = false;

        if (self.raw_instances.items.len > self.instance_buffer_capacity) {
            // TODO resize
        }

        const buffer: [*]venture.model.Instance.Raw = @alignCast(@ptrCast(sdl.SDL_MapGPUTransferBuffer(
            self.scene.journey.gpu_device,
            self.transfer_buffer,
            false
        )));

        @memcpy(buffer[0..self.raw_instances.items.len], self.raw_instances.items);

        sdl.SDL_UnmapGPUTransferBuffer(self.scene.journey.gpu_device, self.transfer_buffer);

        sdl.SDL_UploadToGPUBuffer(
            copy_pass,
            &sdl.SDL_GPUTransferBufferLocation {
                .transfer_buffer = self.transfer_buffer,
                .offset = 0
            },
            &sdl.SDL_GPUBufferRegion {
                .buffer = self.instance_buffer,
                .offset = 0,
                .size = @intCast(self.raw_instances.items.len * @sizeOf(venture.model.Instance.Raw)),
            },
            false
        );
    }
}

pub fn __render(self: *Container, render_pass: ?*sdl.SDL_GPURenderPass) !void {
    if (self.instances.items.len == 0) return;

    try self.model.__setup(render_pass);

    sdl.SDL_BindGPUVertexStorageBuffers(
        render_pass, 
        0,
        &self.instance_buffer, 
        1
    );

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
    sdl.SDL_ReleaseGPUBuffer(self.scene.journey.gpu_device, self.instance_buffer);
    sdl.SDL_ReleaseGPUTransferBuffer(self.scene.journey.gpu_device, self.transfer_buffer);
    for (self.instances.items) |instance| {
        self.scene.journey.allocator.destroy(instance);
    }
    self.instances.deinit(self.scene.journey.allocator);
    self.raw_instances.deinit(self.scene.journey.allocator);
    self.scene.journey.allocator.destroy(self);
}

// shortcuts

pub fn createInstance(self: *Container) !*venture.model.Instance {
    return try venture.model.Instance.create(self);
}
