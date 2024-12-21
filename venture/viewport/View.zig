const std = @import("std");
const venture = @import("venture");

const View = @This();
journey: *venture.core.Journey,

pub const Options = struct {};

pub fn create(journey: *venture.core.Journey, options: Options) !*View {
    const view = try journey.allocator.create(View);
    view.journey = journey;

    _ = options;

    return view;
}

pub fn render(self: *View) !void {
    _ = self;
}

pub fn destroy(self: *View) void {
    self.journey.allocator.destroy(self);
}
