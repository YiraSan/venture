pub const view = @import("view/root.zig");

// init / deinit

const std = @import("std");
const sdl = @import("sdl");

pub const InitError = error {
    SDL_INITIALIZATION_FAILURE,
};

/// This function should be called from your application' main thread
pub fn init() InitError!void {
    const sdl_initialized = (sdl.SDL_WasInit(sdl.SDL_INIT_VIDEO) & sdl.SDL_INIT_VIDEO) == sdl.SDL_INIT_VIDEO;
    if (!sdl_initialized) if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.log.err("Couldn't initialize SDL: {s}", .{ sdl.SDL_GetError() });
        return InitError.SDL_INITIALIZATION_FAILURE;
    };
}

pub fn deinit() void {
    // currently unused, but created for retro-compatibility
}
