pub const Journey = @import("Journey.zig");
pub const View = @import("view/View.zig");
pub const Scene = @import("view/Scene.zig");

// init / deinit

const std = @import("std");
const sdl = @import("sdl");

pub const InitError = error {
    SDLInitFail,
};


fn dummy_log(_: ?*anyopaque, _: c_int, _: sdl.SDL_LogPriority, _: [*c]const u8) callconv(.c) void {}

/// This function should be called from your application' main thread
pub fn init() InitError!void {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.log.err("Couldn't initialize SDL: {s}", .{ sdl.SDL_GetError() });
        return InitError.SDLInitFail;
    }

    // sdl.SDL_SetLogOutputFunction(&dummy_log, null);
    sdl.SDL_SetLogPriorities(sdl.SDL_LOG_PRIORITY_ERROR);
}

pub const Event = union(enum) {
    Quit,
    None,
};

pub fn pollEvent() !Event {
    var event = std.mem.zeroes(sdl.SDL_Event);
    if (!sdl.SDL_PollEvent(&event)) {
        return Event.None;
    }
    return switch (event.type) {
        sdl.SDL_EVENT_QUIT => Event.Quit,
        else => Event.None,
    };
}

pub fn delay(ms: u32) void {
    sdl.SDL_Delay(ms);
}

pub fn deinit() void {
    sdl.SDL_Quit();
}
