const std = @import("std");

const global = @import("global.zig");
const renderer = @import("renderer.zig");
const circuit_widget = @import("circuit_widget.zig");

const component = @import("component.zig");
const circuit = @import("circuit.zig");
const console = @import("console.zig");

const dvui = @import("dvui");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var console_initialized: bool = false;

fn init(win: *dvui.Window) !void {
    _ = win;

    try dvui.addFont(global.font_name, global.font_data, null);
    try dvui.addFont(global.bold_font_name, global.bold_font_data, null);

    try circuit_widget.initKeybinds(allocator);

    // TODO
    global.light_theme.font_body = .{ .id = .fromName(global.font_name), .size = 18 };
    global.light_theme.font_caption = .{ .id = .fromName(global.font_name), .size = 15 };
    global.light_theme.font_title = .{ .id = .fromName(global.font_name), .size = 20 };
    global.light_theme.font_title_1 = .{ .id = .fromName(global.bold_font_name), .size = 19 };
    global.light_theme.font_title_2 = .{ .id = .fromName(global.bold_font_name), .size = 18 };
    global.light_theme.font_title_3 = .{ .id = .fromName(global.bold_font_name), .size = 17 };
    global.light_theme.font_title_4 = .{ .id = .fromName(global.bold_font_name), .size = 16 };

    dvui.themeSet(global.dark_theme);

    circuit.main_circuit = circuit.GraphicCircuit{
        .allocator = allocator,
        .graphic_components = std.ArrayList(component.GraphicComponent){},
        .wires = std.ArrayList(circuit.Wire){},
    };

    console_initialized = true;
}

fn frame() !dvui.App.Result {
    const keep_running = renderer.render(allocator) catch @panic("err");

    return if (keep_running) .ok else .close;
}

pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = global.default_window_width, .h = global.default_window_height },
            .min_size = .{ .w = global.minimum_window_width, .h = global.minimum_window_height },
            .title = "bland",
        },
    },
    .initFn = init,
    .frameFn = frame,
};

pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{
    .logFn = blandLog,
};

pub fn blandLog(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (console_initialized) {
        console.log(message_level, scope, format, args);
    } else {
        dvui.App.logFn(message_level, scope, format, args);
    }
}
