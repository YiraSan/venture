const std = @import("std");
const venture = @import("venture");
const sdl = @import("sdl");

const Window = @This();
journey: *venture.core.Journey,

sdl_window: *sdl.SDL_Window,

pub const Options = struct {
    title: ?[]const u8 = null,
    width: ?u32 = null,
    height: ?u32 = null,
    show_at_creation: bool = false,
};

pub fn create(journey: *venture.core.Journey, options: Options) !*Window {
    const window = try journey.allocator.create(Window);
    window.journey = journey;

    const hide_flag = if (options.show_at_creation) 0 else sdl.SDL_WINDOW_HIDDEN;

    if (sdl.SDL_CreateWindow(
        @ptrCast(options.title orelse "Venture"), 
        @intCast(options.width orelse 640), 
        @intCast(options.height orelse 480), 
        hide_flag
    )) |sdl_window| {
        window.sdl_window = sdl_window;
    } else {
        @panic("failed to create window");
    }

    if (!sdl.SDL_ClaimWindowForGPUDevice(window.journey.gpu_device, window.sdl_window)) {
        @panic("failed to claim window");
    }
    
    return window;
}

pub fn setVisibility(self: *Window, visible: bool) !void {
    if (visible) {
        if (!sdl.SDL_ShowWindow(self.sdl_window)) {
            std.log.err("Failed showing the window: {s}", .{ sdl.SDL_GetError() });
            return error.CannotShow;
        }
    } else {
        if (!sdl.SDL_HideWindow(self.sdl_window)) {
            std.log.err("Failed hidding the window: {s}", .{ sdl.SDL_GetError() });
            return error.CannotHide;
        }
    }
}

pub fn isVisible(self: *Window) bool {
    const flags = sdl.SDL_GetWindowFlags(self.sdl_window);
    return !(flags & sdl.SDL_WINDOW_HIDDEN == sdl.SDL_WINDOW_HIDDEN);
}

pub fn show(self: *Window) !void {
    try self.setVisibility(true);
}


pub fn hide(self: *Window) !void {
    try self.setVisibility(false);
}

pub fn setTitle(self: *Window, title: []const u8) !void {
    if (!sdl.SDL_SetWindowTitle(self.sdl_window, @ptrCast(title))) {
        std.log.err("Cannot set window title: ", .{ sdl.SDL_GetError() });
        return error.CannotSetTitle;
    }
}

pub fn getTitle(self: *Window) []const u8 {
    return std.mem.span(sdl.SDL_GetWindowTitle(self.sdl_window));
}

pub fn getId(self: *Window) u32 {
    return sdl.SDL_GetWindowID(self.sdl_window);
}

pub fn getWidth(self: *Window) u32 {
    var width: c_int = undefined;
    _ = sdl.SDL_GetWindowSizeInPixels(self.sdl_window, &width, null);
    return @intCast(width);
}

pub fn getHeight(self: *Window) u32 {
    var height: c_int = undefined;
    _ = sdl.SDL_GetWindowSizeInPixels(self.sdl_window, null, &height);
    return @intCast(height);
}

pub fn target(self: *Window) venture.render.View.Target {
    return venture.render.View.Target {
        .window = self
    };
}

pub fn destroy(self: *Window) void {
    sdl.SDL_ReleaseWindowFromGPUDevice(self.journey.gpu_device, self.sdl_window);
    sdl.SDL_DestroyWindow(self.sdl_window);
    self.journey.allocator.destroy(self);
}
