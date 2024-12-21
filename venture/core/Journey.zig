const std = @import("std");
const builtin = @import("builtin");
const venture = @import("venture");
const sdl = @import("sdl");

const Journey = @This();
allocator: std.mem.Allocator,

gpu_device: *sdl.SDL_GPUDevice,

pub fn create(allocator: std.mem.Allocator) !*Journey {
    const journey = try allocator.create(Journey);
    journey.allocator = allocator;

    if (sdl.SDL_CreateGPUDevice(
        sdl.SDL_GPU_SHADERFORMAT_SPIRV | sdl.SDL_GPU_SHADERFORMAT_METALLIB | sdl.SDL_GPU_SHADERFORMAT_DXIL,
        comptime builtin.mode == .Debug, null)
    ) |gpu_device| {
        journey.gpu_device = gpu_device;
    } else {
        @panic("unable to create device");
    }

    return journey;
}

pub fn destroy(self: *Journey) void {
    sdl.SDL_DestroyGPUDevice(self.gpu_device);
    self.allocator.destroy(self);
}

// shortcuts

pub inline fn createWindow(self: *Journey, options: venture.viewport.Window.Options) !*venture.viewport.Window {
    return try venture.viewport.Window.create(self, options);
}

pub inline fn createView(self: *Journey, options: venture.viewport.View.Options) !*venture.viewport.View {
    return try venture.viewport.View.create(self, options);
}

pub inline fn createScene(self: *Journey, options: venture.render.Scene.Options) !*venture.render.Scene {
    return try venture.render.Scene.create(self, options);
}