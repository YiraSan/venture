const std = @import("std");
const venture = @import("root");
const sdl = @import("sdl");

const View = @This();
allocator: std.mem.Allocator,
window: *sdl.struct_SDL_Window,

pub const ViewError = error {
    CreationFail,
    ShowFail,
    HideFail,
};

pub fn create(allocator: std.mem.Allocator) !*View {
    const view = try allocator.create(View);
    view.allocator = allocator;

    const window = sdl.SDL_CreateWindow(
        "Venture", 
        360, 
        360, 
        sdl.SDL_WINDOW_METAL
    );

    // TODO check if device has high DPI to enable it

    if (window) |win| {
        view.window = win;
    } else {
        std.log.err("Couldn't initialize window: {s}", .{ sdl.SDL_GetError() });
        return ViewError.CreationFail;
    }

    return view;
}

pub fn show(self: *View) ViewError!void {
    if (!sdl.SDL_ShowWindow(self.window)) {
        std.log.err("Couldn't show window: {s}", .{ sdl.SDL_GetError() });
        return ViewError.ShowFail;
    }
}

pub fn hide(self: *View) ViewError!void {
    if (!sdl.SDL_HideWindow(self.window)) {
        std.log.err("Couldn't hide window: {s}", .{ sdl.SDL_GetError() });
        return ViewError.HideFail;
    }
}

pub fn destroy(self: *View) void {
    sdl.SDL_DestroyWindow(self.window);
    self.allocator.destroy(self);
}
