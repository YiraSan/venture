const std = @import("std");
const builtin = @import("builtin");
const venture = @import("venture");
const sdl = @import("sdl");

const Journey = @This();
allocator: std.mem.Allocator,
timer: std.time.Timer,

gpu_device: *sdl.SDL_GPUDevice,

pub fn create(allocator: std.mem.Allocator) !*Journey {
    const journey = try allocator.create(Journey);
    journey.allocator = allocator;

    journey.timer = try std.time.Timer.start();

    if (sdl.SDL_CreateGPUDevice(
        sdl.SDL_GPU_SHADERFORMAT_SPIRV | sdl.SDL_GPU_SHADERFORMAT_MSL,
        comptime builtin.mode == .Debug, null)
    ) |gpu_device| {
        journey.gpu_device = gpu_device;
    } else {
        @panic("unable to create device");
    }

    return journey;
}

pub fn getTick(self: *Journey) u64 {
    const tick_length: f64 = comptime @as(f64, @floatFromInt(std.time.ns_per_s)) / 60.0;
    const current: f64 = @floatFromInt(self.timer.read());
    return @intFromFloat(current / tick_length);
}

pub fn destroy(self: *Journey) void {
    sdl.SDL_DestroyGPUDevice(self.gpu_device);
    self.allocator.destroy(self);
}

// shortcuts

pub inline fn createWindow(self: *Journey, options: venture.core.Window.Options) !*venture.core.Window {
    return try venture.core.Window.create(self, options);
}

pub inline fn createView(self: *Journey, options: venture.render.View.Options) !*venture.render.View {
    return try venture.render.View.create(self, options);
}

pub inline fn createScene(self: *Journey, options: venture.render.Scene.Options) !*venture.render.Scene {
    return try venture.render.Scene.create(self, options);
}

pub inline fn createModel(self: *Journey, mesh: *const fn(journey: *venture.core.Journey) anyerror!venture.model.Mesh) !*venture.model.Model {
    return try venture.model.Model.create(self, try mesh(self));
}
