const std = @import("std");
const venture = @import("root");
const sdl = @import("sdl");

const View = @This();
allocator: std.mem.Allocator,

pub fn create(allocator: std.mem.Allocator) !*View {
    const view = try allocator.create(View);
    view.allocator = allocator;

    return view;
}

pub fn destroy(self: *View) void {
    
    self.allocator.destroy(self);
}
