const std = @import("std");
const venture = @import("venture");
const wgpu = @import("wgpu");

const Model = @This();
mesh: venture.Mesh,

pub fn init(mesh: venture.Mesh) Model {
    return Model {
        .mesh = mesh,
    };
}

pub fn deinit(self: *Model) void {
    _ = self;    
}
