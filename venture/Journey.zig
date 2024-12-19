const std = @import("std");
const builtin = @import("builtin");
const venture = @import("venture");
const sdl_vulkan = @import("sdl_vulkan");
const wgpu = @import("wgpu");

const Journey = @This();
allocator: std.mem.Allocator,
backend_type: BackendType,
wgpu_instance: wgpu.WGPUInstance,
wgpu_adapter: wgpu.WGPUAdapter,
wgpu_device: wgpu.WGPUDevice,
wgpu_queue: wgpu.WGPUQueue,

pub const BackendType = enum {
    metal,
    vulkan,
    opengl,
};

pub fn create(allocator: std.mem.Allocator) !*Journey {
    const journey = try allocator.create(Journey);
    journey.allocator = allocator;
    journey.wgpu_adapter = null;
    journey.wgpu_device = null;
    journey.wgpu_queue = null;

    journey.wgpu_instance = wgpu.wgpuCreateInstance(null);

    // We check first for vulkan to make sure vulkan will be used if MoltenVK is linked
    if (sdl_vulkan.SDL_Vulkan_LoadLibrary(null)) {
        journey.backend_type = .vulkan;
    } else if (comptime builtin.os.tag == .macos or builtin.os.tag == .ios) {
        journey.backend_type = .metal;
    } else {
        journey.backend_type = .opengl;
    }

    wgpu.wgpuInstanceRequestAdapter(
        journey.wgpu_instance, 
        &wgpu.WGPURequestAdapterOptions {
            .backendType = switch (journey.backend_type) {
                .metal => wgpu.WGPUBackendType_Metal,
                .vulkan => wgpu.WGPUBackendType_Vulkan,
                .opengl => wgpu.WGPUBackendType_OpenGL,
            },
        }, 
        &handle_request_adapter, 
        journey
    );
    if (journey.wgpu_adapter == null) {
        std.log.err("wgpu adapter request failed", .{});
        return error.CreationFail;
    }

    wgpu.wgpuAdapterRequestDevice(
        journey.wgpu_adapter, 
        null, 
        &handle_request_device, 
        journey
    );
    if (journey.wgpu_device == null) {
        std.log.err("wgpu device request failed", .{});
        return error.CreationFail;
    }

    journey.wgpu_queue = wgpu.wgpuDeviceGetQueue(journey.wgpu_device);
    if (journey.wgpu_queue == null) {
        std.log.err("cannot get device queue", .{});
        return error.CreationFail;
    }

    return journey;
}

fn handle_request_adapter(
    _: wgpu.WGPURequestAdapterStatus, 
    adapter: wgpu.WGPUAdapter, 
    _: [*c]const u8, 
    userdata: ?*anyopaque
) callconv(.c) void {
    const self: *Journey = @alignCast(@ptrCast(userdata));
    self.wgpu_adapter = adapter;
}

fn handle_request_device(
    _: wgpu.WGPURequestDeviceStatus, 
    device: wgpu.WGPUDevice, 
    _: [*c]const u8, 
    userdata: ?*anyopaque
) callconv(.c) void {
    const self: *Journey = @alignCast(@ptrCast(userdata));
    self.wgpu_device = device;
}

pub inline fn createView(self: *Journey, options: venture.View.Options) !*venture.View {
    return try venture.View.create(self, options);
}

pub inline fn createScene(self: *Journey, options: venture.Scene.Options) !*venture.Scene {
    return try venture.Scene.create(self, options);
}

pub inline fn createModel(self: *Journey, mesh_builder: *const fn(journey: *venture.Journey) anyerror!venture.Mesh) !*venture.Model {
    return try venture.Model.create(self, try mesh_builder(self));
}

pub fn destroy(self: *Journey) void {
    wgpu.wgpuQueueRelease(self.wgpu_queue);
    wgpu.wgpuDeviceRelease(self.wgpu_device);
    wgpu.wgpuAdapterRelease(self.wgpu_adapter);
    wgpu.wgpuInstanceRelease(self.wgpu_instance);
    self.allocator.destroy(self);
}
