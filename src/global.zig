pub const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_ttf.h");
});

const component = @import("component.zig");

pub const default_window_width = 1024;
pub const default_window_height = 768;

pub const grid_size = 64;
