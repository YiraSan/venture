pub const core = struct {
    pub const Journey = @import("core/Journey.zig");
    pub const Window = @import("core/Window.zig");
};

pub const model = struct {
    
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
    Quit,
};

pub fn poll() ?Event {
    var event = std.mem.zeroes(sdl.SDL_Event);
    if (!sdl.SDL_PollEvent(&event)) {
        return null;
    }

    return switch (event.type) {
        sdl.SDL_EVENT_QUIT => Event.Quit,
        else => null,
    };
}
