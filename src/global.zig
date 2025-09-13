const std = @import("std");

const dvui = @import("dvui");
const SDLBackend = dvui.backend;
comptime {
    std.debug.assert(@hasDecl(SDLBackend, "SDLBackend"));
}
const sdl = SDLBackend.c;

const component = @import("component.zig");
const renderer = @import("renderer.zig");

pub const default_window_width = 1024;
pub const default_window_height = 768;
pub const minimum_window_width = 640;
pub const minimum_window_height = 480;

pub const grid_size = 64;

pub const font_name = "JuliaMono";
pub const font_path = "ttf/JuliaMono-Regular.ttf";
pub const font_data = @embedFile(font_path);
pub const font_size = 18;
