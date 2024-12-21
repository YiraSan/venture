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

    const view = try journey.createView(.{});
    defer view.destroy();

    while (true) {
        if (venture.poll()) |event| switch (event) {
            .Quit => {
                break;
            },
        };

        try view.render();
    }
}
