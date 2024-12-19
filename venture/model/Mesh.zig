const std = @import("std");
const venture = @import("venture");
const wgpu = @import("wgpu");

const Mesh = @This();
vertices: []Vertex,
indices: []u16,

pub fn triangle(journey: *venture.Journey) !Mesh {
    const vertices = try journey.allocator.dupe(Vertex, &[_] Vertex {
        Vertex { .position = .{ -1.0, -1.0, 0.0, 1.0 }, .color = .{ 1.0, 1.0, 0.0, 1.0 } },
        Vertex { .position = .{  1.0, -1.0, 0.0, 1.0 }, .color = .{ 0.0, 1.0, 0.0, 1.0 } },
        Vertex { .position = .{  0.0,  1.0, 0.0, 1.0 }, .color = .{ 1.0, 0.0, 0.0, 1.0 } },
    });
    const indices = try journey.allocator.dupe(u16, &[_] u16 { 0, 1, 2 });
    return Mesh {
        .vertices = vertices,
        .indices = indices,
    };
}

pub fn deinit(self: *Mesh, journey: *venture.Journey) void {
    journey.allocator.free(self.vertices);
    journey.allocator.free(self.indices);
}

pub const Vertex = packed struct(u256) { // 16 + 16 = 256
    position: @Vector(4, f32),
    color: @Vector(4, f32),
};

pub const vertex_attributes = &[_] wgpu.WGPUVertexAttribute {
    wgpu.WGPUVertexAttribute {
        .format = wgpu.WGPUVertexFormat_Float32x4,
        .offset = 0,
        .shaderLocation = 0,
    },
    wgpu.WGPUVertexAttribute {
        .format = wgpu.WGPUVertexFormat_Float32x4,
        .offset = 0 + 16,
        .shaderLocation = 1,
    },
};
