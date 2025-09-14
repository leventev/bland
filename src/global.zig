const std = @import("std");

const dvui = @import("dvui");
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

pub const bold_font_name = "JuliaMonoBold";
pub const bold_font_path = "ttf/JuliaMono-Bold.ttf";
pub const bold_font_data = @embedFile(bold_font_path);

pub const circuit_font_size = 18;

// TODO: make this const and make it nicer
pub var dark_theme = dvui.Theme.builtin.adwaita_dark;
pub var light_theme = dvui.Theme.builtin.adwaita_light;
