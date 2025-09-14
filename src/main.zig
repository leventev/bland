const std = @import("std");

const global = @import("global.zig");
const renderer = @import("renderer.zig");
const component = @import("component.zig");
const circuit = @import("circuit.zig");
const circuit_widget = @import("circuit_widget.zig");

const dvui = @import("dvui");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

fn init(win: *dvui.Window) !void {
    _ = win;

    circuit.components = std.array_list.Managed(component.Component).init(allocator);
    circuit.wires = std.array_list.Managed(circuit.Wire).init(allocator);
    defer circuit.components.deinit();
    defer circuit.wires.deinit();

    try dvui.addFont(global.font_name, global.font_data, null);

    try circuit_widget.initKeybinds(allocator);

    // TODO
    var theme = dvui.Theme.builtin.adwaita_dark;
    theme.font_body = .{ .id = .fromName(global.font_name), .size = 18 };
    theme.font_caption = .{ .id = .fromName(global.font_name), .size = 15 };
    theme.font_title = .{ .id = .fromName(global.font_name), .size = 20 };

    dvui.themeSet(theme);
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
    .logFn = dvui.App.logFn,
};
