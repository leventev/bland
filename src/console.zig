const std = @import("std");
const dvui = @import("dvui");

const LogEntry = struct {
    str: []const u8,
    level: std.log.Level,
};

const log_entry_buffer_size = 1024;
const log_str_buffer_size = log_entry_buffer_size * 80;

var log_entry_buffer: [log_entry_buffer_size]LogEntry = undefined;
var log_str_buffer: [log_str_buffer_size]u8 = undefined;
var log_entry_count: usize = 0;
var log_str_buffer_idx: usize = 0;

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (log_entry_count == log_entry_buffer_size) return;

    const remaining_buf = log_str_buffer[log_str_buffer_idx..];
    var writer = std.Io.Writer.fixed(remaining_buf);
    if (scope == .default) {
        writer.print("{s}: ", .{@tagName(message_level)}) catch return;
    } else {
        writer.print("{s}({s}): ", .{ @tagName(message_level), @tagName(scope) }) catch return;
    }

    writer.print(format, args) catch return;
    writer.printAsciiChar('\n', .{}) catch return;

    log_entry_buffer[log_entry_count] = LogEntry{
        .level = message_level,
        .str = remaining_buf[0..writer.end],
    };

    log_entry_count += 1;
    log_str_buffer_idx += writer.end;
}

pub fn renderConsole() void {
    var vbox = dvui.box(
        @src(),
        .{},
        .{
            .min_size_content = .{ .w = 300, .h = 100 },
            .expand = .both,
            .padding = dvui.Rect.all(8),
            .background = true,
            .border = dvui.Rect{ .y = 2 },
        },
    );
    defer vbox.deinit();

    var scroller = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .background = true,
        .color_fill = dvui.themeGet().color(.content, .fill),
    });
    defer scroller.deinit();

    var tl = dvui.widgetAlloc(dvui.TextLayoutWidget);
    tl.init(
        @src(),
        .{},
        .{
            .expand = .horizontal,
            .background = true,
            .color_fill = dvui.themeGet().color(.content, .fill),
        },
    );
    defer tl.deinit();
    tl.processEvents();

    const err_color = dvui.Color.fromHSLuv(0, 50, 50, 100);
    const warn_color = dvui.Color.fromHSLuv(60, 85, 85, 100);
    const debug_color = dvui.Color.fromHSLuv(300, 35, 55, 100);
    const info_color = dvui.themeGet().text;

    for (0..log_entry_count) |i| {
        const log_entry = log_entry_buffer[i];

        const color = switch (log_entry.level) {
            .info => info_color,
            .debug => debug_color,
            .warn => warn_color,
            .err => err_color,
        };

        tl.addText(log_entry.str, .{
            .color_text = color,
        });
    }
}
