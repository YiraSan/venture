const std = @import("std");
const venture = @import("venture");

const Mesh = @This();
vertices: []Vertex,
indices: []Index,

pub fn triangle(journey: *venture.core.Journey) !Mesh {
    const vertices = try journey.allocator.dupe(Vertex, &[_] Vertex {
        Vertex { .position = .{ -1.0, -1.0, 0.0, 1.0 }, .color = .{ 1.0, 1.0, 0.0, 1.0 } },
        Vertex { .position = .{  1.0, -1.0, 0.0, 1.0 }, .color = .{ 0.0, 1.0, 0.0, 1.0 } },
        Vertex { .position = .{  0.0,  1.0, 0.0, 1.0 }, .color = .{ 1.0, 0.0, 0.0, 1.0 } },
    });
    const indices = try journey.allocator.dupe(Index, &[_] Index { 0, 1, 2 });
    return Mesh {
        .vertices = vertices,
        .indices = indices,
    };
}

pub fn rectangle(journey: *venture.core.Journey) !Mesh {
    const vertices = try journey.allocator.dupe(Vertex, &[_] Vertex {
        Vertex { .position = .{ -1.0, -1.0, 0.0, 1.0 }, .color = .{ 1.0, 1.0, 0.0, 1.0 } },
        Vertex { .position = .{  1.0, -1.0, 0.0, 1.0 }, .color = .{ 0.0, 1.0, 0.0, 1.0 } },
        Vertex { .position = .{  1.0,  1.0, 0.0, 1.0 }, .color = .{ 1.0, 0.0, 0.0, 1.0 } },
        Vertex { .position = .{ -1.0,  1.0, 0.0, 1.0 }, .color = .{ 1.0, 0.0, 0.0, 1.0 } },
    });
    const indices = try journey.allocator.dupe(Index, &[_] Index { 0, 1, 2, 2, 3, 0 });
    return Mesh {
        .vertices = vertices,
        .indices = indices,
    };
}

pub fn deinit(self: *Mesh, journey: *venture.core.Journey) void {
    journey.allocator.free(self.vertices);
    journey.allocator.free(self.indices);
}

pub const Vertex = extern struct {
    position: @Vector(4, f32),
    color: @Vector(4, f32),
};

pub const Index = u16;
