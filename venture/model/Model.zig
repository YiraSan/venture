const std = @import("std");
const venture = @import("venture");
const sdl = @import("sdl");

const Model = @This();
journey: *venture.core.Journey,
mesh: venture.model.Mesh,

vertex_buffer: ?*sdl.SDL_GPUBuffer,
index_buffer: ?*sdl.SDL_GPUBuffer,

pub fn create(journey: *venture.core.Journey, mesh: venture.model.Mesh) !*Model {
    const model = try journey.allocator.create(Model);
    model.journey = journey;
    model.mesh = mesh;

    model.vertex_buffer = null;
    model.index_buffer = null;

    model.vertex_buffer = sdl.SDL_CreateGPUBuffer(
		model.journey.gpu_device,
		&sdl.SDL_GPUBufferCreateInfo {
			.usage = sdl.SDL_GPU_BUFFERUSAGE_VERTEX,
			.size = @intCast(mesh.vertices.len * @sizeOf(venture.model.Mesh.Vertex)),
		}
	);
    if (model.vertex_buffer == null) {
        std.log.err("Failed creating buffer: {s}", .{ sdl.SDL_GetError() });
        return error.FailedCreatingBuffer;
    }

    model.index_buffer = sdl.SDL_CreateGPUBuffer(
		model.journey.gpu_device,
		&sdl.SDL_GPUBufferCreateInfo {
			.usage = sdl.SDL_GPU_BUFFERUSAGE_INDEX,
			.size = @intCast(mesh.indices.len * @sizeOf(venture.model.Mesh.Index)),
		}
	);
    if (model.index_buffer == null) {
        std.log.err("Failed creating buffer: {s}", .{ sdl.SDL_GetError() });
        return error.FailedCreatingBuffer;
    }

    // transfer data

    const vertex_transfer_buffer = sdl.SDL_CreateGPUTransferBuffer(
		model.journey.gpu_device,
		@ptrCast(&sdl.SDL_GPUBufferCreateInfo {
			.usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
			.size = @intCast(mesh.vertices.len * @sizeOf(venture.model.Mesh.Vertex)),
		})
	);
    if (vertex_transfer_buffer == null) {
        std.log.err("Failed creating buffer: {s}", .{ sdl.SDL_GetError() });
        return error.FailedCreatingBuffer;
    }

    const index_transfer_buffer = sdl.SDL_CreateGPUTransferBuffer(
		model.journey.gpu_device,
		@ptrCast(&sdl.SDL_GPUBufferCreateInfo {
			.usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
			.size = @intCast(mesh.indices.len * @sizeOf(venture.model.Mesh.Index)),
		})
	);
    if (index_transfer_buffer == null) {
        std.log.err("Failed creating buffer: {s}", .{ sdl.SDL_GetError() });
        return error.FailedCreatingBuffer;
    }

    const vertex_data: [*]venture.model.Mesh.Vertex = @alignCast(@ptrCast(sdl.SDL_MapGPUTransferBuffer(
		model.journey.gpu_device,
		vertex_transfer_buffer,
		false
	)));

    const index_data: [*]venture.model.Mesh.Index = @alignCast(@ptrCast(sdl.SDL_MapGPUTransferBuffer(
		model.journey.gpu_device,
		index_transfer_buffer,
		false
	)));

    @memcpy(vertex_data[0..model.mesh.vertices.len], model.mesh.vertices);
    @memcpy(index_data[0..model.mesh.indices.len], model.mesh.indices);

    sdl.SDL_UnmapGPUTransferBuffer(model.journey.gpu_device, vertex_transfer_buffer);
    sdl.SDL_UnmapGPUTransferBuffer(model.journey.gpu_device, index_transfer_buffer);

    const upload_command_buffer = sdl.SDL_AcquireGPUCommandBuffer(model.journey.gpu_device);
	const copy_pass = sdl.SDL_BeginGPUCopyPass(upload_command_buffer);

    sdl.SDL_UploadToGPUBuffer(
		copy_pass,
		&sdl.SDL_GPUTransferBufferLocation {
			.transfer_buffer = vertex_transfer_buffer,
			.offset = 0
		},
		&sdl.SDL_GPUBufferRegion {
			.buffer = model.vertex_buffer,
			.offset = 0,
			.size = @intCast(mesh.vertices.len * @sizeOf(venture.model.Mesh.Vertex)),
		},
		false
	);

    sdl.SDL_UploadToGPUBuffer(
		copy_pass,
		&sdl.SDL_GPUTransferBufferLocation {
			.transfer_buffer = index_transfer_buffer,
			.offset = 0
		},
		&sdl.SDL_GPUBufferRegion {
			.buffer = model.index_buffer,
			.offset = 0,
			.size = @intCast(mesh.indices.len * @sizeOf(venture.model.Mesh.Index)),
		},
		false
	);

    sdl.SDL_EndGPUCopyPass(copy_pass);
	if (!sdl.SDL_SubmitGPUCommandBuffer(upload_command_buffer)) {
		std.log.err("Failed submitting command buffer: {s}", .{ sdl.SDL_GetError() });
        return error.FailedSubmittingCommandBuffer;
	}

    sdl.SDL_ReleaseGPUTransferBuffer(model.journey.gpu_device, vertex_transfer_buffer);
	sdl.SDL_ReleaseGPUTransferBuffer(model.journey.gpu_device, index_transfer_buffer);

    return model;
}

pub fn destroy(self: *Model) void {
    sdl.SDL_ReleaseGPUBuffer(self.journey.gpu_device, self.vertex_buffer);
    sdl.SDL_ReleaseGPUBuffer(self.journey.gpu_device, self.index_buffer);
    self.mesh.deinit(self.journey);
    self.journey.allocator.destroy(self);
}

pub fn __setup(self: *Model, render_pass: ?*sdl.SDL_GPURenderPass) !void {
	sdl.SDL_BindGPUVertexBuffers(
		render_pass,
		0,
		&[_] sdl.SDL_GPUBufferBinding {
			sdl.SDL_GPUBufferBinding {
				.buffer = self.vertex_buffer,
				.offset = 0,
			}
		}, 
		1
	);

	sdl.SDL_BindGPUIndexBuffer(
		render_pass,
		&[_] sdl.SDL_GPUBufferBinding {
			sdl.SDL_GPUBufferBinding {
				.buffer = self.index_buffer,
				.offset = 0,
			}
		},
		sdl.SDL_GPU_INDEXELEMENTSIZE_16BIT
	);
}

// shortcuts

pub fn bindTo(self: *Model, scene: *venture.render.Scene) !*venture.model.Container {
	return try venture.model.Container.create(self, scene);
}
