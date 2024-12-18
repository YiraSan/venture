//! The view is the equivalent of a window.

const std = @import("std");
const builtin = @import("builtin");
const venture = @import("venture");
const sdl = @import("sdl");
const wgpu = @import("wgpu");

const View = @This();
journey: *venture.Journey,
window: *sdl.struct_SDL_Window,
native_view: ?*anyopaque,
wgpu_surface: wgpu.WGPUSurface,
wgpu_adapter: wgpu.WGPUAdapter,
wgpu_device: wgpu.WGPUDevice,
wgpu_queue: wgpu.WGPUQueue,

// this will be moved to the scene
render_pipeline: wgpu.WGPURenderPipeline,
surface_config: wgpu.WGPUSurfaceConfiguration,

pub const ViewError = error {
    CreationFail,
    ShowFail,
    HideFail,
};

pub const ViewOptions = struct {
    title: ?[*c]const u8 = null,
    width: ?u32 = null,
    height: ?u32 = null,
};

pub fn create(journey: *venture.Journey, options: ViewOptions) !*View {
    const view = try journey.allocator.create(View);
    view.journey = journey;
    view.native_view = null;
    view.wgpu_adapter = null;
    view.wgpu_device = null;
    view.wgpu_queue = null;

    view.render_pipeline = null;

    const os_flag = if (comptime builtin.os.tag == .macos) 
            sdl.SDL_WINDOW_METAL
        else sdl.SDL_WINDOW_VULKAN;

    const window = sdl.SDL_CreateWindow(
        options.title orelse "Venture", 
        @intCast(options.width orelse 800),
        @intCast(options.height orelse 450), 
        os_flag | sdl.SDL_WINDOW_HIDDEN,
    );

    if (window) |win| {
        view.window = win;
    } else {
        std.log.err("Couldn't initialize window: {s}", .{ sdl.SDL_GetError() });
        return ViewError.CreationFail;
    }

    if (comptime builtin.os.tag == .macos) {
        view.native_view = sdl.SDL_Metal_CreateView(view.window);
        if (view.native_view == null) {
            std.log.err("Couldn't initialize metal view: {s}", .{ sdl.SDL_GetError() });
            return ViewError.CreationFail;
        }

        const metal_layer = sdl.SDL_Metal_GetLayer(view.native_view);
        if (metal_layer == null) {
            std.log.err("Couldn't initialize metal layer: {s}", .{ sdl.SDL_GetError() });
            return ViewError.CreationFail;
        }

        view.wgpu_surface = wgpu.wgpuInstanceCreateSurface(
            view.journey.wgpu_instance,
            &wgpu.WGPUSurfaceDescriptor {
                .nextInChain = @ptrCast(&wgpu.struct_WGPUSurfaceDescriptorFromMetalLayer {
                    .chain = wgpu.WGPUChainedStruct {
                        .sType = wgpu.WGPUSType_SurfaceDescriptorFromMetalLayer
                    },
                    .layer = metal_layer,
                }),
            }
        );
        
    } else {
        unreachable;
    }

    wgpu.wgpuInstanceRequestAdapter(
        view.journey.wgpu_instance, 
        &wgpu.WGPURequestAdapterOptions {
            .compatibleSurface = view.wgpu_surface,
        }, 
        &handle_request_adapter, 
        view
    );
    if (view.wgpu_adapter == null) {
        std.log.err("wgpu adapter request failed", .{});
        return ViewError.CreationFail;
    }

    wgpu.wgpuAdapterRequestDevice(
        view.wgpu_adapter, 
        null, 
        &handle_request_device, 
        view
    );
    if (view.wgpu_device == null) {
        std.log.err("wgpu device request failed", .{});
        return ViewError.CreationFail;
    }

    view.wgpu_queue = wgpu.wgpuDeviceGetQueue(view.wgpu_device);
    if (view.wgpu_queue == null) {
        std.log.err("cannot get device queue", .{});
        return ViewError.CreationFail;
    }

    const shader_module = wgpu.wgpuDeviceCreateShaderModule(view.wgpu_device, &wgpu.WGPUShaderModuleDescriptor {
        .label = "shader.wgsl",
        .nextInChain = @ptrCast(&wgpu.WGPUShaderModuleWGSLDescriptor {
            .chain = wgpu.WGPUChainedStruct {
                .sType = wgpu.WGPUSType_ShaderModuleWGSLDescriptor,
            },
            .code = @embedFile("../shaders/shader.wgsl")
        })
    });
    if (shader_module == null) {
        std.log.err("cannot load shaders", .{});
        return ViewError.CreationFail;
    }

    const pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(
        view.wgpu_device,
        &wgpu.WGPUPipelineLayoutDescriptor {
            .label = "pipeline_layout",
        }
    );
    if (pipeline_layout == null) {
        std.log.err("cannot create pipeline layout", .{});
        return ViewError.CreationFail;
    }

    var surface_capabilities = wgpu.WGPUSurfaceCapabilities {};
    wgpu.wgpuSurfaceGetCapabilities(
        view.wgpu_surface, 
        view.wgpu_adapter, 
        &surface_capabilities
    );

    view.render_pipeline = wgpu.wgpuDeviceCreateRenderPipeline(
        view.wgpu_device,
        &wgpu.WGPURenderPipelineDescriptor {
            .label = "render_pipeline",
            .layout = pipeline_layout,
            .vertex = wgpu.WGPUVertexState {
                .module = shader_module,
                .entryPoint = "vs_main",
            },
            .fragment = &wgpu.WGPUFragmentState {
                .module = shader_module,
                .entryPoint = "fs_main",
                .targetCount = 1,
                .targets = &[_]wgpu.WGPUColorTargetState {
                    wgpu.WGPUColorTargetState {
                        .format = surface_capabilities.formats[0],
                        .writeMask = wgpu.WGPUColorWriteMask_All,
                    }
                },
            },
            .primitive = wgpu.WGPUPrimitiveState {
                .topology = wgpu.WGPUPrimitiveTopology_TriangleList,
            },
            .multisample = wgpu.WGPUMultisampleState {
                .count = 1,
                .mask = 0xFFFFFFFF,
            }
        }
    );
    if (view.render_pipeline == null) {
        std.log.err("cannot create render pipeline", .{});
        return ViewError.CreationFail;
    }

    view.surface_config = wgpu.WGPUSurfaceConfiguration {
        .device = view.wgpu_device,
        .usage = wgpu.WGPUTextureUsage_RenderAttachment,
        .format = surface_capabilities.formats[0],
        .presentMode = wgpu.WGPUPresentMode_Fifo,
        .alphaMode = surface_capabilities.alphaModes[0],
    };

    {
        var width: c_int = undefined;
        var height: c_int = undefined;
        if (!sdl.SDL_GetWindowSizeInPixels(view.window, &width, &height)) {
            unreachable;
        }
        view.surface_config.width = @intCast(width);
        view.surface_config.height = @intCast(height);
    }

    wgpu.wgpuSurfaceConfigure(view.wgpu_surface, &view.surface_config);

    return view;
}

fn handle_request_adapter(
    _: wgpu.WGPURequestAdapterStatus, 
    adapter: wgpu.WGPUAdapter, 
    _: [*c]const u8, 
    userdata: ?*anyopaque
) callconv(.c) void {
    const self: *View = @alignCast(@ptrCast(userdata));
    self.wgpu_adapter = adapter;
}

fn handle_request_device(
    _: wgpu.WGPURequestDeviceStatus, 
    device: wgpu.WGPUDevice, 
    _: [*c]const u8, 
    userdata: ?*anyopaque
) callconv(.c) void {
    const self: *View = @alignCast(@ptrCast(userdata));
    self.wgpu_device = device;
}

pub fn render(self: *View, scene: *venture.Scene) !void {
    var surface_texture: wgpu.WGPUSurfaceTexture = undefined;
    wgpu.wgpuSurfaceGetCurrentTexture(self.wgpu_surface, &surface_texture);
    switch (surface_texture.status) {
        wgpu.WGPUSurfaceGetCurrentTextureStatus_Success => {},
        wgpu.WGPUSurfaceGetCurrentTextureStatus_Timeout,
        wgpu.WGPUSurfaceGetCurrentTextureStatus_Outdated,
        wgpu.WGPUSurfaceGetCurrentTextureStatus_Lost => {
            if (surface_texture.texture != null) {
                wgpu.wgpuTextureRelease(surface_texture.texture);
            }
            var width: c_int = undefined;
            var height: c_int = undefined;
            if (!sdl.SDL_GetWindowSizeInPixels(self.window, &width, &height)) {
                unreachable;
            }
            if (width != 0 and height != 0) {
                self.surface_config.width = @intCast(width);
                self.surface_config.height = @intCast(height);
                wgpu.wgpuSurfaceConfigure(self.wgpu_surface, &self.surface_config);
            }
            return try render(self, scene);
        },
        wgpu.WGPUSurfaceGetCurrentTextureStatus_OutOfMemory,
        wgpu.WGPUSurfaceGetCurrentTextureStatus_DeviceLost,
        wgpu.WGPUSurfaceGetCurrentTextureStatus_Force32 => {
            @panic("fatal error during render acquiring surface texture");
        },
        else => {},
    }
    if (surface_texture.texture == null) {
        return error.CouldntGetSurfaceTexture;
    }

    const texture_view = wgpu.wgpuTextureCreateView(
        surface_texture.texture, null);
    if (texture_view == null) {
        return error.CouldntCreateTextureView;
    }

    const command_encoder = wgpu.wgpuDeviceCreateCommandEncoder(
        self.wgpu_device, 
        &wgpu.WGPUCommandEncoderDescriptor{
            .label = "command_encoder",
        }
    );
    if (command_encoder == null) {
        return error.CouldntCreateCommandEncoder;
    }

    const render_pass_encoder = wgpu.wgpuCommandEncoderBeginRenderPass(
            command_encoder,
            &wgpu.WGPURenderPassDescriptor {
                .label = "render_pass_encoder",
                .colorAttachmentCount = 1,
                .colorAttachments = &[_]wgpu.WGPURenderPassColorAttachment {
                        wgpu.WGPURenderPassColorAttachment {
                            .view = texture_view,
                            .loadOp = wgpu.WGPULoadOp_Clear,
                            .storeOp = wgpu.WGPUStoreOp_Store,
                            .depthSlice = wgpu.WGPU_DEPTH_SLICE_UNDEFINED,
                            .clearValue = wgpu.WGPUColor {
                                .r = 0.0,
                                .g = 0.0,
                                .b = 0.0,
                                .a = 1.0,
                            },
                        },
                    },
            }
    );
    if (render_pass_encoder == null) {
        return error.CouldntCreateRenderPassEncoder;
    }

    wgpu.wgpuRenderPassEncoderSetPipeline(render_pass_encoder, self.render_pipeline);

    try scene.__view_render(self, render_pass_encoder);

    wgpu.wgpuRenderPassEncoderEnd(render_pass_encoder);
    wgpu.wgpuRenderPassEncoderRelease(render_pass_encoder);

    const command_buffer = wgpu.wgpuCommandEncoderFinish(
        command_encoder, 
        &wgpu.WGPUCommandBufferDescriptor {
            .label = "command_buffer",
        }
    );
    if (command_buffer == null) {
        return error.CouldntFinishEncoding;
    }

    wgpu.wgpuQueueSubmit(self.wgpu_queue, 1, &[_]wgpu.WGPUCommandBuffer{command_buffer});
    wgpu.wgpuSurfacePresent(self.wgpu_surface);

    wgpu.wgpuCommandBufferRelease(command_buffer);
    wgpu.wgpuCommandEncoderRelease(command_encoder);
    wgpu.wgpuTextureViewRelease(texture_view);

    wgpu.wgpuTextureRelease(surface_texture.texture);
}

pub fn show(self: *View) ViewError!void {
    if (!sdl.SDL_ShowWindow(self.window)) {
        std.log.err("Couldn't show window: {s}", .{ sdl.SDL_GetError() });
        return ViewError.ShowFail;
    }
}

pub fn hide(self: *View) ViewError!void {
    if (!sdl.SDL_HideWindow(self.window)) {
        std.log.err("Couldn't hide window: {s}", .{ sdl.SDL_GetError() });
        return ViewError.HideFail;
    }
}

pub fn destroy(self: *View) void {
    wgpu.wgpuDeviceRelease(self.wgpu_device);
    if (comptime builtin.os.tag == .macos) {
        sdl.SDL_Metal_DestroyView(self.native_view);
    }
    wgpu.wgpuAdapterRelease(self.wgpu_adapter);
    wgpu.wgpuSurfaceRelease(self.wgpu_surface);
    sdl.SDL_DestroyWindow(self.window);
    self.journey.allocator.destroy(self);
}
