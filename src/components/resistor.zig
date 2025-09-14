const std = @import("std");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");

const dvui = @import("dvui");

const Component = component.Component;
const GridPosition = circuit.GridPosition;

var resistor_counter: usize = 0;

pub fn defaultValue() Component.Inner {
    return Component.Inner{ .resistor = 4.5 };
}

pub fn setNewComponentName(buff: []u8) ![]u8 {
    resistor_counter += 1;
    return std.fmt.bufPrint(buff, "R{}", .{resistor_counter});
}

pub fn getTerminals(
    pos: GridPosition,
    rotation: Component.Rotation,
    terminals: []GridPosition,
) []GridPosition {
    return common.twoTerminalTerminals(pos, rotation, terminals);
}

pub fn getOccupiedGridPositions(
    pos: GridPosition,
    rotation: Component.Rotation,
    occupied: []component.OccupiedGridPosition,
) []component.OccupiedGridPosition {
    return common.twoTerminalOccupiedPoints(pos, rotation, occupied);
}

pub fn centerForMouse(pos: GridPosition, rotation: Component.Rotation) GridPosition {
    return common.twoTerminalCenterForMouse(pos, rotation);
}

fn formatValue(value: f32, buf: []u8) !?[]const u8 {
    // https://juliamono.netlify.app/glyphs/
    const big_omega = '\u{03A9}';
    return try std.fmt.bufPrint(buf, "{d}{u}", .{ value, big_omega });
}

pub fn render(
    circuit_rect: dvui.Rect.Physical,
    grid_pos: GridPosition,
    rot: component.Component.Rotation,
    name: ?[]const u8,
    value: ?f32,
    render_type: renderer.ComponentRenderType,
) void {
    const wire_pixel_len = 25;
    const resistor_length = 2 * global.grid_size - 2 * wire_pixel_len;
    const resistor_width = 28;

    const pos = grid_pos.toCircuitPosition(circuit_rect);

    const resistor_color = renderer.renderColors(render_type).component_color;

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

            renderer.drawRect(rect, resistor_color);
            if (name) |str| {
                renderer.renderCenteredText(
                    dvui.Point{
                        .x = pos.x + global.grid_size,
                        .y = pos.y - (resistor_width / 2 + global.circuit_font_size / 2 + 2),
                    },
                    dvui.Color.white,
                    str,
                );
            }

            if (value_str) |str| {
                renderer.renderCenteredText(
                    dvui.Point{
                        .x = pos.x + global.grid_size,
                        .y = pos.y + resistor_width / 2 + global.circuit_font_size / 2 + 2,
                    },
                    dvui.Color.white,
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

            renderer.drawRect(rect, resistor_color);
            if (name) |str| {
                renderer.renderCenteredText(
                    dvui.Point{
                        .x = pos.x + global.grid_size / 2,
                        .y = pos.y + global.grid_size - (global.circuit_font_size / 2 + 8),
                    },
                    dvui.Color.white,
                    str,
                );
            }

            if (value_str) |str| {
                renderer.renderCenteredText(
                    dvui.Point{
                        .x = pos.x + global.grid_size / 2,
                        .y = pos.y + global.grid_size + (global.circuit_font_size / 2 + 8),
                    },
                    dvui.Color.white,
                    str,
                );
            }
        },
    }
}
