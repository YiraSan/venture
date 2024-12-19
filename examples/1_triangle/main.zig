const std = @import("std");
const builtin = @import("builtin");
const venture = @import("venture");

pub fn main() !void {
    try venture.init();
    defer venture.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) gpa.allocator() else std.heap.c_allocator;

    const journey = try venture.Journey.create(allocator);
    defer journey.destroy();

    const view = try journey.createView(.{});
    defer view.destroy(); 
    
    const scene = try journey.createScene();
    defer scene.destroy();

    const model = try journey.createModel(venture.Mesh.triangle);
    defer model.destroy();

    const container = try model.bindTo(scene);

    const instance = try container.newInstance();
    _ = instance;

    try view.render(scene);
    try view.show();

    while (true) {
        defer venture.delay(15);
        switch (try venture.pollEvent()) {
            .Quit => {
                break;
            },
            else => {}
        }
        try view.render(scene);
    }
}
