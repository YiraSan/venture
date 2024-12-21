const std = @import("std");
const venture = @import("venture");
const sdl = @import("sdl");

const View = @This();
journey: *venture.core.Journey,

target: ?Target,
scene: ?*venture.render.Scene,
clear_color: ?Color,

graphics_pipeline: ?*sdl.SDL_GPUGraphicsPipeline,

pub const Target = union(enum) {
    window: *venture.core.Window,
};

// TODO move that to a utils file (later)
pub const Color = struct {
    r: f32, g: f32, b: f32, a: f32,
};

pub const Options = struct {
    target: ?Target = null,
    scene: ?*venture.render.Scene = null,
    clear_color: ?Color = null,
};

fn loadShader(
    self: *View,
    entrypoint: []const u8,
    stage: sdl.SDL_GPUShaderStage,
    num_samplers: u32,
    num_storage_buffers: u32,
    num_storage_textures: u32,
    num_uniform_buffers: u32,
) !*sdl.SDL_GPUShader {

    const shaderFormats = sdl.SDL_GetGPUShaderFormats(self.journey.gpu_device);

    var code: []const u8 = undefined;
    var code_format = sdl.SDL_GPU_SHADERFORMAT_INVALID;
    
    if (shaderFormats & sdl.SDL_GPU_SHADERFORMAT_SPIRV == sdl.SDL_GPU_SHADERFORMAT_SPIRV) {
		code = @embedFile("../shaders/shader.spv");
        code_format = sdl.SDL_GPU_SHADERFORMAT_SPIRV;
	} else if (shaderFormats & sdl.SDL_GPU_SHADERFORMAT_MSL == sdl.SDL_GPU_SHADERFORMAT_MSL) {
		code = @embedFile("../shaders/shader.metal");
        code_format = sdl.SDL_GPU_SHADERFORMAT_MSL;
	} else {
        @panic("no supported shader format");
    }

    const shader = if (sdl.SDL_CreateGPUShader(self.journey.gpu_device, 
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

pub fn create(journey: *venture.core.Journey, options: Options) !*View {
    const view = try journey.allocator.create(View);
    view.journey = journey;

    // set to null in order to avoid segfault
    view.target = null;
    view.scene = null;
    view.graphics_pipeline = null;
    view.clear_color = null;

    view.setClearColor(options.clear_color);
    view.setScene(options.scene);
    try view.setTarget(options.target);

    return view;
}

pub fn setClearColor(self: *View, color: ?Color) void {
    self.clear_color = color;
}

pub fn setTarget(self: *View, target: ?Target) !void {
    if (target) |targ| {

        if (self.target) |_| {
            sdl.SDL_ReleaseGPUGraphicsPipeline(self.journey.gpu_device, self.graphics_pipeline);
        }

        const vertexShader = try self.loadShader(
            "vs_main", 
            sdl.SDL_GPU_SHADERSTAGE_VERTEX, 
            0, 
            0, 
            0, 
            0);

        const fragmentShader = try self.loadShader(
            "fs_main", 
            sdl.SDL_GPU_SHADERSTAGE_FRAGMENT, 
            0, 
            0, 
            0, 
            0);
        
        self.graphics_pipeline = sdl.SDL_CreateGPUGraphicsPipeline(
            self.journey.gpu_device,
            &sdl.SDL_GPUGraphicsPipelineCreateInfo {
                .target_info = .{
                    .num_color_targets = 1,
                    .color_target_descriptions = &[_] sdl.SDL_GPUColorTargetDescription {
                        sdl.SDL_GPUColorTargetDescription {
                            .format = switch (targ) {
                                .window => |win| sdl.SDL_GetGPUSwapchainTextureFormat(self.journey.gpu_device, win.sdl_window)
                            },
                        }
                    },
                },

                .vertex_input_state = .{
                    .num_vertex_buffers = 1,
                    .vertex_buffer_descriptions = &[_] sdl.SDL_GPUVertexBufferDescription {
                        sdl.SDL_GPUVertexBufferDescription {
                            .slot = 0,
                            .input_rate = sdl.SDL_GPU_VERTEXINPUTRATE_VERTEX,
                            .instance_step_rate = 0,
                            .pitch = 32, // float4 * 2
                        }
                    },

                    .num_vertex_attributes = 2,
                    .vertex_attributes = &[_] sdl.SDL_GPUVertexAttribute { 
                        sdl.SDL_GPUVertexAttribute {
                            .buffer_slot = 0,
                            .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
                            .location = 0,
                            .offset = 0
                        }, sdl.SDL_GPUVertexAttribute {
                            .buffer_slot = 0,
                            .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
                            .location = 1,
                            .offset = 16 // float4 * 1
                        }
                    }
                },

                .primitive_type = sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
                .vertex_shader = vertexShader,
                .fragment_shader = fragmentShader
            },
        );

        // TODO graphics pipeline builder will be added to dynamically change the pipeline
        // TODO shaders will be moved to journey

        sdl.SDL_ReleaseGPUShader(self.journey.gpu_device, vertexShader);
        sdl.SDL_ReleaseGPUShader(self.journey.gpu_device, fragmentShader);

    }

    self.target = target;
}

pub fn setScene(self: *View, scene: ?*venture.render.Scene) void {
    self.scene = scene;
}

pub fn getScene(self: *View) ?*venture.render.Scene {
    return self.scene;
}

pub fn render(self: *View) !void {
    if (self.target) |target| {

        const command_buffer = sdl.SDL_AcquireGPUCommandBuffer(self.journey.gpu_device);
        if (command_buffer == null) {
            std.log.err("Cannot acquire command buffer: {s}", .{ sdl.SDL_GetError() });
            return error.CannotAcquireCommandBuffer;
        }

        var texture: ?*sdl.SDL_GPUTexture = undefined;
        var texture_width: u32 = undefined;
        var texture_height: u32 = undefined;

        switch (target) {
            .window => |win| {
                // TODO 3.2.0 use WaitAndAcquire
                if (!sdl.SDL_AcquireGPUSwapchainTexture(
                    command_buffer,
                    win.sdl_window,
                    &texture,
                    &texture_width,
                    &texture_height
                )) {
                    std.log.err("Cannot acquire window texture: {s}", .{ sdl.SDL_GetError() });
                    return error.CannotAcquireTargetTexture;
                }
            },
        }

        if (self.scene) |scene| {
            const copy_pass = sdl.SDL_BeginGPUCopyPass(command_buffer);

            try scene.__remap(copy_pass);

            sdl.SDL_EndGPUCopyPass(copy_pass);
        }

        const render_pass = sdl.SDL_BeginGPURenderPass(
            command_buffer, 
            &sdl.SDL_GPUColorTargetInfo {
                .texture = texture,
                .clear_color = if (self.clear_color) |cc| .{ 
                    .r = cc.r, 
                    .g = cc.g, 
                    .b = cc.b, 
                    .a = cc.a 
                } else .{ 
                    .r = 0.0, 
                    .g = 0.0, 
                    .b = 0.0, 
                    .a = 1.0 
                },
                .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
                .store_op = sdl.SDL_GPU_STOREOP_STORE,
            }, 
            1, 
            null
        );

        sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.graphics_pipeline);

        // TODO set camera buffers

        if (self.scene) |scene| {
            try scene.__render(render_pass);
        }

        sdl.SDL_EndGPURenderPass(render_pass);

        if (!sdl.SDL_SubmitGPUCommandBuffer(command_buffer)) {
            std.log.err("Failed submitting command buffer: {s}", .{ sdl.SDL_GetError() });
            return error.FailedSubmittingCommandBuffer;
        }
    }
}

pub fn destroy(self: *View) void {
    if (self.target) |_| {
        sdl.SDL_ReleaseGPUGraphicsPipeline(self.journey.gpu_device, self.graphics_pipeline);
    }
    self.journey.allocator.destroy(self);
}
