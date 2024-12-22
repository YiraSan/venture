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
        .scene = scene,
        .projection = .orthographic,
    });
    defer view.destroy();

    const model = try journey.createModel(venture.model.Mesh.cube);
    defer model.destroy();

    const container = try model.bindTo(scene);
    defer container.destroy();
    
    for (0..20) |i| {
        const instance = try container.createInstance();

        const margin = 4.0;

        const row = @as(f32, @floatFromInt(i % 5)) * margin;
        const column = @as(f32, @floatFromInt(i % 4)) * margin;

        const x = row - 8.0;
        const y = 6.0 - column;

        instance.setCoordinate(x, y, 15.0);
        instance.update();
    }
    defer {
        for (0..20) |i| {
            container.instances.items[i].destroy();
        }
    }
    
    while (true) {
        if (venture.poll()) |event| switch (event) {
            .quit => {
                break;
            },
            else => {}
        };

        for (0..20) |i| {
            const instance = container.instances.items[i];
            const fi = @as(f32, @floatFromInt(i)) * 9.0 * std.math.pi / 180.0;
            instance.setRotation(
                -@as(f32, @floatFromInt(journey.getTick())) * std.math.pi / 180.0 + fi, 
                @as(f32, @floatFromInt(journey.getTick())) * std.math.pi / 180.0 - fi, 
                fi
            );
            instance.update();
        }

        try view.render();
    }
}
