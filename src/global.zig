const std = @import("std");

const dvui = @import("dvui");
const component = @import("component.zig");
const renderer = @import("renderer.zig");

pub const default_window_width = 1024;
pub const default_window_height = 768;
pub const minimum_window_width = 640;
pub const minimum_window_height = 480;

pub const grid_size = 64;

pub const font_name = "JetBrainsMono";
pub const font_path = "ttf/JetBrainsMono-Regular.ttf";
pub const font_data = @embedFile(font_path);

pub const bold_font_name = "JetBrainsMonoBold";
pub const bold_font_path = "ttf/JetBrainsMono-Bold.ttf";
pub const bold_font_data = @embedFile(bold_font_path);

pub const circuit_font_size = 18;

// TODO: make this const and make it nicer

const accent = dvui.Color.fromHSLuv(25, 55, 55, 100);
const err = dvui.Color{ .r = 0xe0, .g = 0x1b, .b = 0x24 };

// DARK constants
const dark_fill = dvui.Color.fromHSLuv(200, 5, 13, 100);
const dark_err = dvui.Color{ .r = 0xc0, .g = 0x1c, .b = 0x28 };

const dark_fg = dvui.Color.fromHSLuv(200, 5, 85, 100);

const dark_accent_accent = accent.lighten(12);
const dark_accent_fill_hover = accent.lighten(9);
const dark_accent_border = accent.lighten(17);

const dark_err_accent = dark_err.lighten(14);
const dark_err_fill_hover = err.lighten(9);
const dark_err_fill_press = err.lighten(16);
const dark_err_border = err.lighten(20);

// LIGHT constants
const light_fill = dvui.Color.fromHSLuv(200, 5, 83, 100);
const light_fill_light = light_fill.lighten(3);
const light_fill_dark = light_fill.lighten(-3);
const light_err = dvui.Color{ .r = 0xc0, .g = 0x1c, .b = 0x28 };

const light_fg = dvui.Color.fromHSLuv(200, 5, 15, 100);

const light_accent = accent.lighten(10);
const light_accent_fill_hover = light_accent.lighten(-5);
const light_accent_fill_press = light_accent.lighten(-10);
const light_accent_border = light_accent.lighten(-50);

const light_err_accent = dark_err.lighten(-14);
const light_err_fill_hover = err.lighten(-9);
const light_err_fill_press = err.lighten(-16);
const light_err_border = err.lighten(-20);

pub const dark_theme = dark: {
    @setEvalBranchQuota(50000);
    break :dark dvui.Theme{
        .name = "Bland Dark",
        .dark = true,
        .font_body = .{ .id = .fromName(font_name), .size = 18 },
        .font_heading = .{ .id = .fromName(bold_font_name), .size = 18 },
        .font_caption_heading = .{ .id = .fromName(bold_font_name), .size = 17 },
        .font_caption = .{ .id = .fromName(font_name), .size = 15, .line_height_factor = 1.1 },
        .font_title = .{ .id = .fromName(font_name), .size = 20, .line_height_factor = 1.1 },
        .font_title_1 = .{ .id = .fromName(bold_font_name), .size = 19 },
        .font_title_2 = .{ .id = .fromName(bold_font_name), .size = 18 },
        .font_title_3 = .{ .id = .fromName(bold_font_name), .size = 17 },
        .font_title_4 = .{ .id = .fromName(bold_font_name), .size = 16 },

        .focus = accent,

        .fill = dark_fill,
        .fill_hover = dark_fill.lighten(10),
        .fill_press = dark_fill.lighten(15),
        .text = dark_fg,
        .text_select = .{ .r = 0x32, .g = 0x60, .b = 0x98 },
        .border = dark_fill.lighten(20),

        .control = .{
            .fill = dark_fill.lighten(6),
            .fill_hover = dark_fill.lighten(10),
            .fill_press = dark_fill.lighten(15),
        },

        .window = .{
            .fill = dark_fill.lighten(3),
        },

        .highlight = .{
            .fill = accent,
            .fill_hover = dark_accent_fill_hover,
            .fill_press = dark_accent_accent,
            .text = dark_fg,
            .border = dark_accent_border,
        },

        .err = .{
            .fill = dark_err,
            .fill_hover = dark_err_fill_hover,
            .fill_press = dark_err_fill_press,
            .text = dark_fg,
            .border = dark_err_border,
        },
    };
};

pub const light_theme = dark: {
    @setEvalBranchQuota(50000);
    break :dark dvui.Theme{
        .name = "Bland Light",
        .dark = false,
        .font_body = .{ .id = .fromName(font_name), .size = 18 },
        .font_heading = .{ .id = .fromName(bold_font_name), .size = 18 },
        .font_caption_heading = .{ .id = .fromName(bold_font_name), .size = 17 },
        .font_caption = .{ .id = .fromName(font_name), .size = 15, .line_height_factor = 1.1 },
        .font_title = .{ .id = .fromName(font_name), .size = 20, .line_height_factor = 1.1 },
        .font_title_1 = .{ .id = .fromName(bold_font_name), .size = 19 },
        .font_title_2 = .{ .id = .fromName(bold_font_name), .size = 18 },
        .font_title_3 = .{ .id = .fromName(bold_font_name), .size = 17 },
        .font_title_4 = .{ .id = .fromName(bold_font_name), .size = 16 },

        .focus = accent,

        .fill = light_fill_dark,
        .fill_hover = light_fill_dark.lighten(-5),
        .fill_press = light_fill_dark.lighten(-10),
        .text = light_fg,
        .text_select = .{ .r = 0x32, .g = 0x60, .b = 0x98 },
        .border = light_fill.lighten(-50),

        .control = .{
            .fill = light_fill_light,
            .fill_hover = light_fill_light.lighten(5),
            .fill_press = light_fill_light.lighten(10),
        },

        .window = .{
            .fill = light_fill,
        },

        .highlight = .{
            .fill = light_accent,
            .fill_hover = light_accent_fill_hover,
            .fill_press = light_accent_fill_press,
            .text = light_fg.lighten(70),
            .border = light_accent_border,
        },

        .err = .{
            .fill = light_err,
            .fill_hover = light_err_fill_hover,
            .fill_press = light_err_fill_press,
            .text = light_fg,
            .border = light_err_border,
        },
    };
};
