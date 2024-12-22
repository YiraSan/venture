const std = @import("std");
const builtin = @import("builtin");
const venture = @import("venture");

pub fn main() !void {
    try venture.init();
    defer venture.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) gpa.allocator() else std.heap.c_allocator;

    const journey = try venture.core.Journey.create(allocator);
    defer journey.destroy();

    const window = try journey.createWindow(.{ .show_at_creation = true });
    defer window.destroy();

    const scene = try journey.createScene(.{});
    defer scene.destroy();

    const view = try journey.createView(.{ 
        .target = window.target(),
        .scene = scene
    });
    defer view.destroy();

    const model = try journey.createModel(venture.model.Mesh.triangle);
    defer model.destroy();

    const container = try model.bindTo(scene);
    defer container.destroy();

    const instance = try container.createInstance();
    defer instance.destroy();

    instance.setCoordinate(0.0, 0.0, 2.5);
    instance.update();

    while (true) {
        if (venture.poll()) |event| switch (event) {
            .quit => {
                break;
            },
            else => {}
        };

        try view.render();
    }
}
