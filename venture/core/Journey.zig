const std = @import("std");
const builtin = @import("builtin");
const venture = @import("venture");
const sdl = @import("sdl");

const Journey = @This();
allocator: std.mem.Allocator,
timer: std.time.Timer,

gpu_device: *sdl.SDL_GPUDevice,

vertex_shader: ?*sdl.SDL_GPUShader,
fragment_shader: ?*sdl.SDL_GPUShader,

pub fn create(allocator: std.mem.Allocator) !*Journey {
    const journey = try allocator.create(Journey);
    journey.allocator = allocator;

    journey.timer = try std.time.Timer.start();

    if (sdl.SDL_CreateGPUDevice(
        sdl.SDL_GPU_SHADERFORMAT_SPIRV | sdl.SDL_GPU_SHADERFORMAT_MSL, // | sdl.SDL_GPU_SHADERFORMAT_DXBC | sdl.SDL_GPU_SHADERFORMAT_DXIL
        comptime builtin.mode == .Debug, null)
    ) |gpu_device| {
        journey.gpu_device = gpu_device;
    } else {
        @panic("unable to create device");
    }

    journey.vertex_shader = try journey.loadShader(
        "shader",
        "vs_main", 
        sdl.SDL_GPU_SHADERSTAGE_VERTEX, 
        0, 
        1, 
        0, 
        1);

    journey.fragment_shader = try journey.loadShader(
        "shader",
        "fs_main", 
        sdl.SDL_GPU_SHADERSTAGE_FRAGMENT, 
        0, 
        0, 
        0, 
        0);

    return journey;
}

pub fn getTick(self: *Journey) u64 {
    const tick_length: f64 = comptime @as(f64, @floatFromInt(std.time.ns_per_s)) / 60.0;
    const current: f64 = @floatFromInt(self.timer.read());
    return @intFromFloat(current / tick_length);
}

pub fn destroy(self: *Journey) void {
    sdl.SDL_ReleaseGPUShader(self.gpu_device, self.vertex_shader);
    sdl.SDL_ReleaseGPUShader(self.gpu_device, self.fragment_shader);
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

// utils

fn loadShader(
    self: *Journey,
    comptime file_name: []const u8,
    entrypoint: []const u8,
    stage: sdl.SDL_GPUShaderStage,
    num_samplers: u32,
    num_storage_buffers: u32,
    num_storage_textures: u32,
    num_uniform_buffers: u32,
) !*sdl.SDL_GPUShader {

    const shaderFormats = sdl.SDL_GetGPUShaderFormats(self.gpu_device);

    var code: []const u8 = undefined;
    var code_format = sdl.SDL_GPU_SHADERFORMAT_INVALID;
    
    if (shaderFormats & sdl.SDL_GPU_SHADERFORMAT_SPIRV == sdl.SDL_GPU_SHADERFORMAT_SPIRV) {
		code = @embedFile("../shaders/" ++ file_name ++ ".spv");
        code_format = sdl.SDL_GPU_SHADERFORMAT_SPIRV;
	} else if (shaderFormats & sdl.SDL_GPU_SHADERFORMAT_MSL == sdl.SDL_GPU_SHADERFORMAT_MSL) {
		code = @embedFile("../shaders/" ++ file_name ++ ".metal");
        code_format = sdl.SDL_GPU_SHADERFORMAT_MSL;
	} else {
        @panic("no supported shader format");
    }

    const shader = if (sdl.SDL_CreateGPUShader(self.gpu_device, 
        &sdl.SDL_GPUShaderCreateInfo {
            .code = @ptrCast(code),
            .code_size = code.len,
            .entrypoint = @ptrCast(entrypoint),
            .format = @intCast(code_format),
            .stage = stage,
            .num_samplers = num_samplers,
            .num_storage_buffers = num_storage_buffers,
            .num_storage_textures = num_storage_textures,
            .num_uniform_buffers = num_uniform_buffers,
            
        },
    )) |shdr| shdr else {
        std.log.err("Failed creating shaders: {s}", .{ sdl.SDL_GetError() });
        return error.InvalidShader;
    };

    return shader;

}
