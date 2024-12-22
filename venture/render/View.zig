const std = @import("std");
const venture = @import("venture");
const sdl = @import("sdl");
const zmath = @import("zmath");

const View = @This();
journey: *venture.core.Journey,

target: ?Target,
scene: ?*venture.render.Scene,
clear_color: ?Color,

graphics_pipeline: ?*sdl.SDL_GPUGraphicsPipeline,

camera_coordinate: @Vector(3, f32),
camera_rotation: @Vector(3, f32),

camera_uniform: zmath.Mat,
projection_matrix: zmath.Mat,

projection: Projection,
texture_width: u32,
texture_height: u32,

depth_texture: ?*sdl.SDL_GPUTexture,

pub const Target = union(enum) {
    window: *venture.core.Window,
};

// TODO move that to a utils file (later)
pub const Color = struct {
    r: f32, g: f32, b: f32, a: f32,
};

pub const Projection = union(enum) {
    orthographic,
    perspective: struct {
        fov: f32
    }
};

pub const Options = struct {
    target: ?Target = null,
    scene: ?*venture.render.Scene = null,
    clear_color: ?Color = null,
    projection: ?Projection = null,
};

pub fn create(journey: *venture.core.Journey, options: Options) !*View {
    const view = try journey.allocator.create(View);
    view.journey = journey;

    // set to null in order to avoid segfault
    view.target = null;
    view.scene = null;
    view.graphics_pipeline = null;
    view.clear_color = null;

    view.projection = Projection { .perspective = .{ .fov = 60.0 * std.math.pi / 180.0 } };

    view.setClearColor(options.clear_color);
    view.setScene(options.scene);
    try view.setTarget(options.target);

    view.camera_uniform = zmath.identity();

    view.camera_coordinate = .{ 0.0, 0.0, 0.0 };
    view.camera_rotation = .{ 0.0, 0.0, 0.0 };

    view.setProjection(options.projection);

    view.update();

    return view;
}

pub fn setProjection(self: *View, projection: ?Projection) void {
    if (projection) |proj| {
        self.projection = proj;
    }

    const width: f32 = @floatFromInt(self.texture_width);
    const height: f32 = @floatFromInt(self.texture_height);

    self.projection_matrix = switch (self.projection) {
        .orthographic => zmath.orthographicLh(width/25.0, height/25.0, 0.01, 100),
        .perspective => |perspective| zmath.perspectiveFovLh(perspective.fov, width / height, 0.01, 100),
    };
}

pub fn setClearColor(self: *View, color: ?Color) void {
    self.clear_color = color;
}

pub fn setTarget(self: *View, target: ?Target) !void {
    if (target) |targ| {

        if (self.target) |_| {
            sdl.SDL_ReleaseGPUGraphicsPipeline(self.journey.gpu_device, self.graphics_pipeline);
        }
        
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
                    .has_depth_stencil_target = true,
                    .depth_stencil_format = sdl.SDL_GPU_TEXTUREFORMAT_D32_FLOAT_S8_UINT
                },

                .depth_stencil_state = .{
                    .enable_stencil_test = true,
                    .enable_depth_write = true,
                    .compare_op = sdl.SDL_GPU_COMPAREOP_LESS,
                    .front_stencil_state = .{
                        .compare_op = sdl.SDL_GPU_COMPAREOP_EQUAL, // Passer uniquement si les valeurs correspondent
                        .depth_fail_op = sdl.SDL_GPU_STENCILOP_KEEP,
                        .pass_op = sdl.SDL_GPU_STENCILOP_REPLACE,  // Remplacer la valeur du stencil en cas de succès
                        .fail_op = sdl.SDL_GPU_STENCILOP_KEEP
                    },
                    .back_stencil_state = .{
                        .compare_op = sdl.SDL_GPU_COMPAREOP_EQUAL,
                        .depth_fail_op = sdl.SDL_GPU_STENCILOP_KEEP,
                        .pass_op = sdl.SDL_GPU_STENCILOP_REPLACE,
                        .fail_op = sdl.SDL_GPU_STENCILOP_KEEP
                    },
                },

                .rasterizer_state = .{
                    .cull_mode = sdl.SDL_GPU_CULLMODE_BACK,
                    .fill_mode = sdl.SDL_GPU_FILLMODE_FILL,
                    .front_face = sdl.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE
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
                .vertex_shader = self.journey.vertex_shader,
                .fragment_shader = self.journey.fragment_shader
            },
        );

        self.depth_texture = sdl.SDL_CreateGPUTexture(
            self.journey.gpu_device, 
        &sdl.SDL_GPUTextureCreateInfo {
                .@"type" = sdl.SDL_GPU_TEXTURETYPE_2D,
                .format = sdl.SDL_GPU_TEXTUREFORMAT_D32_FLOAT_S8_UINT,
                .width = 640,
                .height = 480,
                .layer_count_or_depth = 1,
                .num_levels = 1,
                .sample_count = 0,
                .usage = sdl.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
                .props = 0,
            }
        );

        // TODO graphics pipeline builder will be added to dynamically change the pipeline

    }

    self.target = target;

    self.texture_width = if (self.target) |targ| switch (targ) {
        .window => |win| win.getWidth()
    } else 250;

    self.texture_height = if (self.target) |targ| switch (targ) {
        .window => |win| win.getHeight()
    } else 250;
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

        if (texture_width != self.texture_width or texture_height != self.texture_height) {
            self.texture_width = texture_width;
            self.texture_height = texture_height;
            self.setProjection(null);
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
            &sdl.SDL_GPUDepthStencilTargetInfo {
                .clear_depth = 1.0,
                .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
                .store_op = sdl.SDL_GPU_STOREOP_DONT_CARE,
                .stencil_load_op = sdl.SDL_GPU_LOADOP_DONT_CARE,
                .stencil_store_op = sdl.SDL_GPU_STOREOP_DONT_CARE,
                .texture = self.depth_texture,
                .cycle = true,
            }
        );

        sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.graphics_pipeline);

        sdl.SDL_PushGPUVertexUniformData(
            command_buffer, 
            0, 
            &self.camera_uniform, 
            @sizeOf(zmath.Mat)
        );

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

pub fn update(self: *View) void {
    const rotation_matrix = zmath.quatToMat(zmath.quatFromRollPitchYaw(
        self.camera_rotation[0], self.camera_rotation[1], self.camera_rotation[2]
    ));

    const translation_matrix = zmath.translation(
        -self.camera_coordinate[0], -self.camera_coordinate[1], -self.camera_coordinate[2]
    );

    const view_matrix = zmath.mul(translation_matrix, rotation_matrix);

    self.camera_uniform = zmath.mul(self.projection_matrix, view_matrix);
}

pub fn setCoordinate(self: *View, x: ?f32, y: ?f32, z: ?f32) void {
    if (x) |c| self.camera_coordinate[0] = c;
    if (y) |c| self.camera_coordinate[1] = c;
    if (z) |c| self.camera_coordinate[2] = c;
}

pub fn setRotation(self: *View, x: ?f32, y: ?f32, z: ?f32) void {
    if (x) |c| self.camera_rotation[0] = c;
    if (y) |c| self.camera_rotation[1] = c;
    if (z) |c| self.camera_rotation[2] = c;
}

pub fn destroy(self: *View) void {
    sdl.SDL_ReleaseGPUTexture(self.journey.gpu_device, self.depth_texture);
    if (self.target) |_| {
        sdl.SDL_ReleaseGPUGraphicsPipeline(self.journey.gpu_device, self.graphics_pipeline);
    }
    self.journey.allocator.destroy(self);
}
