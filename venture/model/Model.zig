const std = @import("std");
const venture = @import("venture");
const wgpu = @import("wgpu");

pub const Container = @import("Container.zig");

const Model = @This();
journey: *venture.Journey,
mesh: venture.Mesh,

vertex_buffer: wgpu.WGPUBuffer,
index_buffer: wgpu.WGPUBuffer,

// This is here only for safety purpose.
containers: std.ArrayListUnmanaged(*Container),
containers_lock: std.Thread.RwLock,

const COPY_BUFFER_ALIGNMENT: u64 = 4;

pub fn create(journey: *venture.Journey, mesh: venture.Mesh) !*Model {
    const model = try journey.allocator.create(Model);
    model.journey = journey;
    model.mesh = mesh;

    model.containers = try std.ArrayListUnmanaged(*Container).initCapacity(model.journey.allocator, 128);
    model.containers_lock = .{};

    if (mesh.vertices.len == 0) {
        model.vertex_buffer = wgpu.wgpuDeviceCreateBuffer(
            model.journey.wgpu_device,
            &wgpu.WGPUBufferDescriptor{
                .label = "vertex_buffer",
                .mappedAtCreation = 0,
                .usage = wgpu.WGPUBufferUsage_Vertex,
                .size = 0,
            },
        );
    } else {
        const unpadded_size = mesh.vertices.len * @sizeOf(venture.Mesh.Vertex);
        const align_mask = COPY_BUFFER_ALIGNMENT - 1;
        const padded_size = @max((unpadded_size + align_mask) & ~align_mask, COPY_BUFFER_ALIGNMENT);
        model.vertex_buffer = wgpu.wgpuDeviceCreateBuffer(
            model.journey.wgpu_device,
            &wgpu.WGPUBufferDescriptor{
                .label = "vertex_buffer",
                .mappedAtCreation = 1,
                .usage = wgpu.WGPUBufferUsage_Vertex,
                .size = padded_size,
            },
        );

        const buf = wgpu.wgpuBufferGetMappedRange(model.vertex_buffer, 0, padded_size);
        _ = wgpu.__builtin_memcpy(buf, mesh.vertices.ptr, unpadded_size);
        wgpu.wgpuBufferUnmap(model.vertex_buffer);
    }

    if (mesh.indices.len == 0) {
        model.index_buffer = wgpu.wgpuDeviceCreateBuffer(
            model.journey.wgpu_device,
            &wgpu.WGPUBufferDescriptor{
                .label = "index_buffer",
                .mappedAtCreation = 0,
                .usage = wgpu.WGPUBufferUsage_Index,
                .size = 0,
            },
        );
    } else {
        const unpadded_size = mesh.indices.len * @sizeOf(u16);
        const align_mask = COPY_BUFFER_ALIGNMENT - 1;
        const padded_size = @max((unpadded_size + align_mask) & ~align_mask, COPY_BUFFER_ALIGNMENT);
        model.index_buffer = wgpu.wgpuDeviceCreateBuffer(
            model.journey.wgpu_device,
            &wgpu.WGPUBufferDescriptor{
                .label = "index_buffer",
                .mappedAtCreation = 1,
                .usage = wgpu.WGPUBufferUsage_Index,
                .size = padded_size,
            },
        );

        const buf = wgpu.wgpuBufferGetMappedRange(model.index_buffer, 0, padded_size);
        _ = wgpu.__builtin_memcpy(buf, mesh.indices.ptr, unpadded_size);
        wgpu.wgpuBufferUnmap(model.index_buffer);
    }

    return model;
}

/// This will cause the destruction of all containers made from this model.
/// Destroying a model that have an active container, won't break the scene linked to it.
pub fn destroy(self: *Model) void {

    {
        for (self.containers.items) |container| {
            {
                container.scene.containers_lock.lock();
                defer container.scene.containers_lock.unlock();

                for (0.., container.scene.containers.items) |i, con| {
                    if (con == container) {
                        _ = container.scene.containers.swapRemove(i);
                        break;
                    }
                }
            }
            container._destroy();
        }
        self.containers.deinit(self.journey.allocator);
    }

    wgpu.wgpuBufferRelease(self.vertex_buffer);
    wgpu.wgpuBufferRelease(self.index_buffer);
    self.mesh.deinit(self.journey);
    self.journey.allocator.destroy(self);
}

pub fn bindTo(self: *Model, scene: *venture.Scene) !*Container {
    const container = try self.journey.allocator.create(Container);
    container.model = self;
    container.scene = scene;

    container.instances = try std.ArrayListUnmanaged(*Container._privateInstance).initCapacity(self.journey.allocator, 64);
    container.first_scheduled_index = -1;
    container.instances_locks = .{};

    {
        self.containers_lock.lock();
        defer self.containers_lock.unlock();
        try self.containers.append(self.journey.allocator, container);
    }

    {
        container.scene.containers_lock.lock();
        defer container.scene.containers_lock.unlock();
        try container.scene.containers.append(self.journey.allocator, container);
    }

    return container;
}
