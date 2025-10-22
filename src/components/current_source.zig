const std = @import("std");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");

const dvui = @import("dvui");

const MNA = @import("../mna.zig").MNA;

const Component = component.Component;
const GridPosition = circuit.GridPosition;
const Rotation = circuit.Rotation;

const FloatType = circuit.FloatType;

var current_source_counter: usize = 0;

pub fn defaultValue(_: std.mem.Allocator) !Component.Inner {
    return Component.Inner{ .current_source = 1 };
}
pub fn setNewComponentName(buff: []u8) ![]u8 {
    current_source_counter += 1;
    return std.fmt.bufPrint(buff, "I{}", .{current_source_counter});
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
    return try std.fmt.bufPrint(buf, "{d}A", .{value});
}

pub fn render(
    circuit_rect: dvui.Rect.Physical,
    grid_pos: GridPosition,
    rot: Rotation,
    name: ?[]const u8,
    value: ?FloatType,
    render_type: renderer.ComponentRenderType,
) void {
    const pos = grid_pos.toCircuitPosition(circuit_rect);

    const total_len = 2 * global.grid_size;
    const middle_len = 50;
    const arrow_len = 30;
    const arrowhead_len = 8;
    const wire_len = (total_len - middle_len) / 2;

    const render_colors = render_type.colors();
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
                .pixel_length = wire_len,
            }, render_type);
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = dvui.Point{
                    .x = pos.x + global.grid_size * 2,
                    .y = pos.y,
                },
                .direction = .horizontal,
                .pixel_length = -wire_len,
            }, render_type);

            var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());
            defer path.deinit();

            path.addArc(
                dvui.Point.Physical{
                    .x = pos.x + global.grid_size,
                    .y = pos.y,
                },
                middle_len / 2,
                dvui.math.pi * 2,
                0,
                false,
            );

            path.build().stroke(.{
                .color = render_colors.component_color,
                .thickness = thickness,
            });

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

            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x + global.grid_size - arrow_len / 2,
                    .y = pos.y,
                },
                dvui.Point.Physical{
                    .x = pos.x + global.grid_size + arrow_len / 2,
                    .y = pos.y,
                },
                render_colors.component_color,
                thickness,
            );

            const sign: f32 = if (rot == .right) 1 else -1;
            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x + global.grid_size + sign * arrow_len / 2,
                    .y = pos.y,
                },
                dvui.Point.Physical{
                    .x = pos.x + global.grid_size + sign * (arrow_len / 2 - arrowhead_len),
                    .y = pos.y + arrowhead_len,
                },
                render_colors.component_color,
                thickness,
            );
            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x + global.grid_size + sign * arrow_len / 2,
                    .y = pos.y,
                },
                dvui.Point.Physical{
                    .x = pos.x + global.grid_size + sign * (arrow_len / 2 - arrowhead_len),
                    .y = pos.y - arrowhead_len,
                },
                render_colors.component_color,
                thickness,
            );
        },
        .top, .bottom => {
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = pos,
                .direction = .vertical,
                .pixel_length = wire_len,
            }, render_type);
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = dvui.Point{
                    .x = pos.x,
                    .y = pos.y + global.grid_size * 2,
                },
                .direction = .vertical,
                .pixel_length = -wire_len,
            }, render_type);

            var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());
            defer path.deinit();

            path.addArc(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + global.grid_size,
                },
                middle_len / 2,
                dvui.math.pi * 2,
                0,
                false,
            );

            path.build().stroke(.{
                .color = render_colors.component_color,
                .thickness = thickness,
            });

            if (name) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + global.grid_size / 2,
                        .y = pos.y + global.grid_size / 3,
                    },
                    dvui.themeGet().color(.content, .text),
                    str,
                );
            }

            if (value_str) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + global.grid_size / 2,
                        .y = pos.y + 2 * global.grid_size - global.grid_size / 3,
                    },
                    dvui.themeGet().color(.content, .text),
                    str,
                );
            }

            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + global.grid_size - arrow_len / 2,
                },
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + global.grid_size + arrow_len / 2,
                },
                render_colors.component_color,
                thickness,
            );

            const sign: f32 = if (rot == .bottom) 1 else -1;
            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + global.grid_size + sign * arrow_len / 2,
                },
                dvui.Point.Physical{
                    .x = pos.x + arrowhead_len,
                    .y = pos.y + global.grid_size + sign * (arrow_len / 2 - arrowhead_len),
                },
                render_colors.component_color,
                thickness,
            );
            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + global.grid_size + sign * arrow_len / 2,
                },
                dvui.Point.Physical{
                    .x = pos.x - arrowhead_len,
                    .y = pos.y + global.grid_size + sign * (arrow_len / 2 - arrowhead_len),
                },
                render_colors.component_color,
                thickness,
            );
        },
    }
}

pub fn renderPropertyBox(current: *FloatType) void {
    dvui.label(@src(), "current", .{}, .{
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
        .value = current,
        .show_min_max = true,
    }, .{
        .color_fill = dvui.themeGet().color(.control, .fill),
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_body,
        .expand = .horizontal,
        .margin = dvui.Rect.all(4),
    });

    dvui.label(@src(), "A", .{}, .{
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_title,
        .margin = dvui.Rect.all(4),
        .padding = dvui.Rect.all(4),
        .gravity_y = 0.5,
    });
}

pub fn stampMatrix(
    i: FloatType,
    terminal_node_ids: []const usize,
    mna: *MNA,
    current_group_2_idx: ?usize,
) void {
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    // TODO: explain how stamping works
    if (current_group_2_idx) |curr_idx| {
        mna.stampVoltageCurrent(v_plus, curr_idx, 1);
        mna.stampVoltageCurrent(v_minus, curr_idx, -1);
        mna.stampCurrentCurrent(curr_idx, curr_idx, 1);
        mna.stampCurrentRHS(curr_idx, i);
    } else {
        mna.stampVoltageRHS(v_plus, -i);
        mna.stampVoltageRHS(v_minus, i);
    }
}
