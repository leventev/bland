const std = @import("std");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");
const dvui = @import("dvui");
const MNA = @import("../MNA.zig");

const Component = component.Component;
const GridPosition = circuit.GridPosition;
const Rotation = circuit.Rotation;

const FloatType = circuit.FloatType;

var resistor_counter: usize = 0;

pub fn defaultValue(_: std.mem.Allocator) !Component.Inner {
    return Component.Inner{ .resistor = 1 };
}

pub fn setNewComponentName(buff: []u8) ![]u8 {
    resistor_counter += 1;
    return std.fmt.bufPrint(buff, "R{}", .{resistor_counter});
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
    // https://juliamono.netlify.app/glyphs/
    const big_omega = '\u{03A9}';
    return try std.fmt.bufPrint(buf, "{d}{u}", .{ value, big_omega });
}

pub fn render(
    circuit_rect: dvui.Rect.Physical,
    grid_pos: GridPosition,
    rot: Rotation,
    name: ?[]const u8,
    value: ?FloatType,
    render_type: renderer.ComponentRenderType,
) void {
    const wire_pixel_len = 25;
    const resistor_length = 2 * global.grid_size - 2 * wire_pixel_len;
    const resistor_width = 28;

    const pos = grid_pos.toCircuitPosition(circuit_rect);

    const resistor_color = render_type.colors().component_color;
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

            const rect = dvui.Rect.Physical{
                .x = pos.x + wire_pixel_len,
                .y = pos.y - resistor_width / 2,
                .w = resistor_length,
                .h = resistor_width,
            };

            renderer.drawRect(rect, resistor_color, thickness);
            if (name) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + global.grid_size,
                        .y = pos.y - (resistor_width / 2 + global.circuit_font_size / 2 + 2),
                    },
                    dvui.themeGet().color(.content, .text),
                    str,
                );
            }

            if (value_str) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + global.grid_size,
                        .y = pos.y + resistor_width / 2 + global.circuit_font_size / 2 + 2,
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

            const rect = dvui.Rect.Physical{
                .x = pos.x - resistor_width / 2,
                .y = pos.y + wire_pixel_len,
                .w = resistor_width,
                .h = resistor_length,
            };

            renderer.drawRect(rect, resistor_color, thickness);
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

pub fn renderPropertyBox(r: *FloatType) void {
    dvui.label(@src(), "resistance", .{}, .{
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
        .value = r,
        .show_min_max = true,
        .min = 0.00001,
    }, .{
        .color_fill = dvui.themeGet().color(.control, .fill),
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_body,
        .expand = .horizontal,
        .margin = dvui.Rect.all(4),
    });

    dvui.label(@src(), "\u{03A9}", .{}, .{
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_title,
        .margin = dvui.Rect.all(4),
        .padding = dvui.Rect.all(4),
        .gravity_y = 0.5,
    });
}

pub fn stampMatrix(
    r: FloatType,
    terminal_node_ids: []const usize,
    mna: *MNA,
    current_group_2_idx: ?usize,
    angular_frequency: FloatType,
) void {
    _ = angular_frequency;
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    const g = 1 / r;

    // TODO: explain how stamping works
    if (current_group_2_idx) |curr_idx| {
        mna.stampVoltageCurrent(v_plus, curr_idx, 1);
        mna.stampVoltageCurrent(v_minus, curr_idx, -1);
        mna.stampCurrentVoltage(curr_idx, v_plus, 1);
        mna.stampCurrentVoltage(curr_idx, v_minus, -1);
        mna.stampCurrentCurrent(curr_idx, curr_idx, -r);
    } else {
        mna.stampVoltageVoltage(v_plus, v_plus, g);
        mna.stampVoltageVoltage(v_plus, v_minus, -g);
        mna.stampVoltageVoltage(v_minus, v_plus, -g);
        mna.stampVoltageVoltage(v_minus, v_minus, g);
    }
}
