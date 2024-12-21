const std = @import("std");
const venture = @import("venture");

const View = @This();
journey: *venture.core.Journey,

scene: ?*venture.render.Scene,

pub const Options = struct {
    scene: ?*venture.render.Scene = null,
};

pub fn create(journey: *venture.core.Journey, options: Options) !*View {
    const view = try journey.allocator.create(View);
    view.journey = journey;
    view.scene = options.scene;

    return view;
}

pub fn setScene(self: *View, scene: ?*venture.render.Scene) void {
    self.scene = scene;
}

pub fn getScene(self: *View) ?*venture.render.Scene {
    return self.scene;
}

pub fn render(self: *View) !void {
    _ = self;
}

pub fn destroy(self: *View) void {
    self.journey.allocator.destroy(self);
}
