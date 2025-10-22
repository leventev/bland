const std = @import("std");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");

const dvui = @import("dvui");

const Component = component.Component;
const GridPosition = circuit.GridPosition;
const Rotation = circuit.Rotation;

const FloatType = circuit.FloatType;

var capacitor_counter: usize = 0;

pub fn defaultValue(_: std.mem.Allocator) !Component.Inner {
    return Component.Inner{ .capacitor = 1 };
}

pub fn setNewComponentName(buff: []u8) ![]u8 {
    capacitor_counter += 1;
    return std.fmt.bufPrint(buff, "C{}", .{capacitor_counter});
}

pub fn getTerminals(
    pos: GridPosition,
    rotation: Rotation,
    terminals: []GridPosition,
) []GridPosition {
    return common.twoTerminalTerminals(pos, rotation, terminals);
}

pub fn getOccupiedGridPositions(
    pos: GridPosition,
    rotation: Rotation,
    occupied: []component.OccupiedGridPosition,
) []component.OccupiedGridPosition {
    return common.twoTerminalOccupiedPoints(pos, rotation, occupied);
}

pub fn centerForMouse(pos: GridPosition, rotation: Rotation) GridPosition {
    return common.twoTerminalCenterForMouse(pos, rotation);
}

fn formatValue(value: FloatType, buf: []u8) !?[]const u8 {
    return try std.fmt.bufPrint(buf, "{d}F", .{value});
}

pub fn render(
    circuit_rect: dvui.Rect.Physical,
    grid_pos: GridPosition,
    rot: Rotation,
    name: ?[]const u8,
    value: ?FloatType,
    render_type: renderer.ComponentRenderType,
) void {
    const wire_pixel_len = 55;
    const plate_width = 50;

    const pos = grid_pos.toCircuitPosition(circuit_rect);

    const capacitor_color = render_type.colors().component_color;
    const thickness = render_type.thickness();

    var buff: [256]u8 = undefined;
    const value_str = if (value) |val| formatValue(
        val,
        buff[0..],
    ) catch unreachable else null;

    switch (rot) {
        .left, .right => {
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = pos,
                .direction = .horizontal,
                .pixel_length = wire_pixel_len,
            }, render_type);
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = dvui.Point{
                    .x = pos.x + global.grid_size * 2,
                    .y = pos.y,
                },
                .direction = .horizontal,
                .pixel_length = -wire_pixel_len,
            }, render_type);

            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x + wire_pixel_len,
                    .y = pos.y - plate_width / 2,
                },
                dvui.Point.Physical{
                    .x = pos.x + wire_pixel_len,
                    .y = pos.y + plate_width / 2,
                },
                capacitor_color,
                thickness,
            );

            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x + 2 * global.grid_size - wire_pixel_len,
                    .y = pos.y - plate_width / 2,
                },
                dvui.Point.Physical{
                    .x = pos.x + 2 * global.grid_size - wire_pixel_len,
                    .y = pos.y + plate_width / 2,
                },
                capacitor_color,
                thickness,
            );

            if (name) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + global.grid_size / 3,
                        .y = pos.y - global.grid_size / 4,
                    },
                    dvui.themeGet().color(.content, .text),
                    str,
                );
            }

            if (value_str) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + 2 * global.grid_size - global.grid_size / 3,
                        .y = pos.y - global.grid_size / 4,
                    },
                    dvui.themeGet().color(.content, .text),
                    str,
                );
            }
        },
        .bottom, .top => {
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = pos,
                .direction = .vertical,
                .pixel_length = wire_pixel_len,
            }, render_type);
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = dvui.Point{
                    .x = pos.x,
                    .y = pos.y + global.grid_size * 2,
                },
                .direction = .vertical,
                .pixel_length = -wire_pixel_len,
            }, render_type);

            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x - plate_width / 2,
                    .y = pos.y + wire_pixel_len,
                },
                dvui.Point.Physical{
                    .x = pos.x + plate_width / 2,
                    .y = pos.y + wire_pixel_len,
                },
                capacitor_color,
                thickness,
            );

            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x - plate_width / 2,
                    .y = pos.y + 2 * global.grid_size - wire_pixel_len,
                },
                dvui.Point.Physical{
                    .x = pos.x + plate_width / 2,
                    .y = pos.y + 2 * global.grid_size - wire_pixel_len,
                },
                capacitor_color,
                thickness,
            );

            if (name) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + global.grid_size / 2,
                        .y = pos.y + global.grid_size - (global.circuit_font_size / 2 + 8),
                    },
                    dvui.themeGet().color(.content, .text),
                    str,
                );
            }

            if (value_str) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + global.grid_size / 2,
                        .y = pos.y + global.grid_size + (global.circuit_font_size / 2 + 8),
                    },
                    dvui.themeGet().color(.content, .text),
                    str,
                );
            }
        },
    }
}

pub fn renderPropertyBox(c: *FloatType) void {
    dvui.label(@src(), "capacitance", .{}, .{
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_body,
    });

    var box = dvui.box(
        @src(),
        .{ .dir = .horizontal },
        .{
            .expand = .horizontal,
        },
    );
    defer box.deinit();

    _ = dvui.textEntryNumber(@src(), FloatType, .{
        .value = c,
        .show_min_max = true,
        .min = std.math.floatMin(FloatType),
    }, .{
        .color_fill = dvui.themeGet().color(.control, .fill),
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_body,
        .expand = .horizontal,
        .margin = dvui.Rect.all(4),
    });

    dvui.label(@src(), "F", .{}, .{
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_title,
        .margin = dvui.Rect.all(4),
        .padding = dvui.Rect.all(4),
        .gravity_y = 0.5,
    });
}

pub fn stampMatrix(
    c: FloatType,
    terminal_node_ids: []const usize,
    mna: *circuit.MNA,
    current_group_2_idx: ?usize,
) void {
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    _ = c;
    _ = mna;
    _ = current_group_2_idx;
    _ = v_plus;
    _ = v_minus;
}
