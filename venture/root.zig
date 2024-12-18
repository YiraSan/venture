pub const View = @import("view/View.zig");

// init / deinit

const std = @import("std");
const sdl = @import("sdl");

pub const InitError = error {
    SDL_INITIALIZATION_FAILURE,
};

/// This function should be called from your application' main thread
pub fn init() InitError!void {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.log.err("Couldn't initialize SDL: {s}", .{ sdl.SDL_GetError() });
        return InitError.SDL_INITIALIZATION_FAILURE;
    }
}

pub fn delay(ms: u32) void {
    sdl.SDL_Delay(ms);
}

pub fn deinit() void {
    sdl.SDL_Quit();
}
