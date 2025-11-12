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

    var tl = dvui.TextLayoutWidget.init(
        @src(),
        .{},
        .{
            .expand = .horizontal,
            .background = true,
            .color_fill = dvui.themeGet().color(.content, .fill),
        },
    );
    defer tl.deinit();
    tl.install(.{});
    tl.processEvents();

    for (0..log_entry_count) |i| {
        const log_entry = log_entry_buffer[i];

        const color = switch (log_entry.level) {
            .info => dvui.Color{ .r = 210, .g = 210, .b = 210 },
            .debug => dvui.Color{ .r = 200, .g = 140, .b = 200 },
            .warn => dvui.Color{ .r = 230, .g = 180, .b = 90 },
            .err => dvui.Color{ .r = 210, .g = 120, .b = 120 },
        };

        tl.addText(log_entry.str, .{
            .color_text = color,
        });
    }
}
