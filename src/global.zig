const std = @import("std");

const dvui = @import("dvui");
const SDLBackend = dvui.backend;
comptime {
    std.debug.assert(@hasDecl(SDLBackend, "SDLBackend"));
}
const sdl = SDLBackend.c;

const component = @import("component.zig");

pub const default_window_width = 1024;
pub const default_window_height = 768;

pub const grid_size = 64;

pub const font_name = "JuliaMono";
pub const font_path = "ttf/JuliaMono-Regular.ttf";
pub const font_data = @embedFile(font_path);
pub const font_size = 18;

pub const sidebar_title_font = dvui.Font{
    .name = font_name,
    .size = 22,
};

pub const sidebar_font = dvui.Font{
    .name = font_name,
    .size = 19,
};

pub const sidebar_bg_color = dvui.Color{
    .r = 40,
    .g = 40,
    .b = 55,
    .a = 255,
};

pub const sidebar_button_hover_color = dvui.Color{
    .r = 60,
    .g = 60,
    .b = 80,
    .a = 255,
};

pub const sidebar_button_selected_color = dvui.Color{
    .r = 50,
    .g = 50,
    .b = 65,
    .a = 255,
};

pub const sidebar_title_bg_color = dvui.Color{
    .r = 35,
    .g = 35,
    .b = 48,
    .a = 255,
};

pub const sidebar_border_color = dvui.Color{
    .r = 30,
    .g = 30,
    .b = 43,
    .a = 255,
};

pub const sidebar_text_color_normal = dvui.Color{
    .r = 220,
    .g = 220,
    .b = 220,
    .a = 255,
};
