//! Should technically be called "InstanceContainer"

const std = @import("std");
const venture = @import("venture");
const wgpu = @import("wgpu");

const Container = @This();
model: *venture.Model,
scene: *venture.Scene,

first_scheduled_index: isize,

// lockShared() is used to edit data from one instance while ensuring no remapping is currently done.
// lock() is used to edit the global array or when remapping/rendering.
instances: std.ArrayListUnmanaged(*_privateInstance),
instances_locks: std.Thread.RwLock, 

pub fn destroy(self: *Container) void {
    {
        self.scene.containers_lock.lock();
        defer self.scene.containers_lock.unlock();

        for (0.., self.scene.containers.items) |i, container| {
            if (container == self) {
                _ = self.scene.containers.swapRemove(i);
                break;
            }
        }
    }

    {
        self.model.containers_lock.lock();
        defer self.model.containers_lock.unlock();

        for (0.., self.model.containers.items) |i, container| {
            if (container == self) {
                _ = self.model.containers.swapRemove(i);
                break;
            }
        }
    }

    self._destroy();
}

/// Users should not use that function.
pub fn _destroy(self: *Container) void {
    {
        self.instances_locks.lock();
        defer self.instances_locks.unlock();
        for (self.instances.items) |instance| {
            self.model.journey.allocator.destroy(instance);
        }
        self.instances.deinit(self.model.journey.allocator);
    }

    self.model.journey.allocator.destroy(self);
}

// Instances

/// This struct is intended to be used everywhere in your game design, changed as many times as you want.
/// However, only functions from this struct should be called to ensure safe behavior.
pub const Instance = struct {
    instance_ref: *_privateInstance,

    pub inline fn getContainer(self: *Instance) *Container {
        return self.instance_ref.container;
    }

    pub fn clone(self: *Instance) Instance {
        _ = self.instance_ref.rc.fetchAdd(1, .acq_rel);
        return Instance{ .instance_ref = self.instance_ref };
    }

    /// Using this instance reference after dropping it will result in undefined behavior.
    pub fn drop(self: *Instance) void {
        if (self.instance_ref.rc.fetchMin(1, .acq_rel) == 0) {
            self.instance_ref.remove();
        }
    }
};

pub const _privateInstance = struct {
    container: *Container,
    index: usize,
    rc: std.atomic.Value(usize),
    scheduled_remap: bool,

    fn remove(self: *_privateInstance) void {
        {
            self.container.instances_locks.lock();
            defer self.container.instances_locks.unlock();
            // basically a modified swapRemove
            const i = self.index;
            const array = self.container.instances;
            if (array.items.len - 1 == i) {
                array.pop();
            } else {
                const old_item = array.items[i];
                old_item.index = i;
                old_item.scheduled_remap = true;
                if (self.container.first_scheduled_index == -1) {
                    self.container.first_scheduled_index = i;
                } else {
                    self.container.first_scheduled_index = @min(self.container.first_scheduled_index, i);
                }
                array.items[i] = array.pop();
            }
        }
        self.container.model.journey.allocator.destroy(self);
    }
};

pub fn newInstance(self: *Container) !Instance {
    const instance = try self.model.journey.allocator.create(_privateInstance);
    instance.container = self;
    instance.index = self.instances.items.len;
    instance.rc = std.atomic.Value(usize).init(1);
    instance.scheduled_remap = true; // first mapping

    self.instances_locks.lock();
    defer self.instances_locks.unlock();
    try self.instances.append(self.model.journey.allocator, instance);
    return Instance{
        .instance_ref = instance,
    };
}

pub fn __render(
    self: *Container,
    render_pass_encoder: wgpu.WGPURenderPassEncoder,
) !void {
    if (
        self.model.mesh.vertices.len == 0 or
        self.model.mesh.indices.len == 0 or
        self.instances.items.len == 0
    ) { return; }


    {
        self.instances_locks.lock();
        defer self.instances_locks.unlock();

        if (self.first_scheduled_index > -1) {
            // TODO remap instances
        }

        // reset
        self.first_scheduled_index = -1;
    }

    wgpu.wgpuRenderPassEncoderSetVertexBuffer(
        render_pass_encoder, 
        0, self.model.vertex_buffer, 
        0, 
        self.model.mesh.vertices.len * @sizeOf(venture.Mesh.Vertex)
    );

    wgpu.wgpuRenderPassEncoderSetIndexBuffer(
        render_pass_encoder, 
        self.model.index_buffer, 
        wgpu.WGPUIndexFormat_Uint16, 
        0, 
        self.model.mesh.indices.len * @sizeOf(u16)
    );

    wgpu.wgpuRenderPassEncoderDraw(render_pass_encoder, @intCast(self.model.mesh.vertices.len), @intCast(self.instances.items.len), 0, 0);
}
