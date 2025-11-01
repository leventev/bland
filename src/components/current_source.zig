const std = @import("std");
const bland = @import("bland");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");
const dvui = @import("dvui");

const Component = component.Component;
const GridPosition = circuit.GridPosition;
const Rotation = circuit.Rotation;

const Float = bland.Float;

const current_source_module = bland.component.current_source_module;

var current_source_counter: usize = 0;

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

pub fn render(
    circuit_rect: dvui.Rect.Physical,
    grid_pos: GridPosition,
    rot: Rotation,
    name: ?[]const u8,
    value: ?Float,
    render_type: renderer.ComponentRenderType,
) void {
    const pos = grid_pos.toCircuitPosition(circuit_rect);

    const total_len = 2 * global.grid_size;
    const middle_len = 50;
    const arrow_len = 20;
    const arrowhead_len = 5;
    const wire_len = (total_len - middle_len) / 2;

    const render_colors = render_type.colors();
    const thickness = render_type.thickness();

    var buff: [256]u8 = undefined;
    const value_str = if (value) |val| current_source_module.formatValue(
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

pub fn renderPropertyBox(current: *Float) void {
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

    _ = dvui.textEntryNumber(@src(), Float, .{
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
