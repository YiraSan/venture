pub const core = struct {
    pub const Journey = @import("core/Journey.zig");
    pub const Window = @import("core/Window.zig");
};

pub const model = struct {
    pub const Container = @import("model/Container.zig");
    pub const Instance = @import("model/Instance.zig");
    pub const Mesh = @import("model/Mesh.zig");
    pub const Model = @import("model/Model.zig");
};

pub const render = struct {
    pub const Scene = @import("render/Scene.zig");
    pub const View = @import("render/View.zig");
};

// ... //

const std = @import("std");
const sdl = @import("sdl");

pub fn init() !void {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        @panic("cannot initialize venture's backend");
    }
}

pub fn deinit() void {
    sdl.SDL_Quit();
}

pub const Event = union(enum) {
    /// `window_id`: u32.
    /// Obtainable from `window.getId()`
    window_moved: u32,
    /// `window_id`: u32.
    /// Obtainable from `window.getId()`
    window_resized: u32,
    /// `window_id`: u32.
    /// Obtainable from `window.getId()`
    window_mouse_enter: u32,
    /// `window_id`: u32.
    /// Obtainable from `window.getId()`
    window_mouse_leave: u32,
    /// `window_id`: u32.
    /// Obtainable from `window.getId()`
    window_exposed: u32,
    /// `window_id`: u32.
    /// Obtainable from `window.getId()`
    window_occluded: u32,
    /// This event is only triggered if there are multiple windows.
    /// With one window, .quit is triggered.
    ///
    /// `window_id`: u32.
    /// Obtainable from `window.getId()`
    window_close_request: u32,
    quit,
};

pub fn poll() ?Event {
    var event = std.mem.zeroes(sdl.SDL_Event);
    if (!sdl.SDL_PollEvent(&event)) {
        return null;
    }

    return switch (event.type) {
        sdl.SDL_EVENT_WINDOW_MOVED => Event { .window_moved = event.window.windowID },
        sdl.SDL_EVENT_WINDOW_RESIZED => Event { .window_resized = event.window.windowID },
        sdl.SDL_EVENT_WINDOW_MOUSE_ENTER => Event { .window_mouse_enter = event.window.windowID },
        sdl.SDL_EVENT_WINDOW_MOUSE_LEAVE => Event { .window_mouse_leave = event.window.windowID },
        sdl.SDL_EVENT_WINDOW_EXPOSED => Event { .window_exposed = event.window.windowID },
        sdl.SDL_EVENT_WINDOW_OCCLUDED => Event { .window_occluded = event.window.windowID },
        sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED => Event { .window_close_request = event.window.windowID },

        sdl.SDL_EVENT_QUIT => Event.quit,
        else => null,
    };
}
