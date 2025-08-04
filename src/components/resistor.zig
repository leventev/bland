const std = @import("std");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");

const Component = component.Component;
const GridPosition = circuit.GridPosition;

var resistor_counter: usize = 0;

pub fn defaultValue() Component.Inner {
    return Component.Inner{ .resistor = 4 };
}

pub fn formatValue(value: u32, buf: []u8) !?[]const u8 {
    // https://juliamono.netlify.app/glyphs/
    const big_omega = '\u{03A9}';
    return try std.fmt.bufPrint(buf, "{}{u}", .{ value, big_omega });
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

pub fn render(
    pos: GridPosition,
    rot: component.Component.Rotation,
    name: ?[]const u8,
    render_type: renderer.ComponentRenderType,
) void {
    const wire_pixel_len = 25;
    const resistor_length = 2 * global.grid_size - 2 * wire_pixel_len;
    const resistor_width = 28;

    const world_pos = renderer.WorldPosition.fromGridPosition(pos);
    const coords = renderer.ScreenPosition.fromWorldPosition(world_pos);

    const resistor_color = renderer.renderColors(render_type).component_color;

    var buff: [256]u8 = undefined;
    const value = formatValue(
        4,
        buff[0..],
    ) catch unreachable;

    switch (rot) {
        .left, .right => {
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = coords,
                .direction = .horizontal,
                .pixel_length = wire_pixel_len,
            }, render_type);
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = renderer.ScreenPosition{
                    .x = coords.x + global.grid_size * 2,
                    .y = coords.y,
                },
                .direction = .horizontal,
                .pixel_length = -wire_pixel_len,
            }, render_type);

            const rect = renderer.Rect{
                .x = coords.x + wire_pixel_len,
                .y = coords.y - resistor_width / 2,
                .w = resistor_length,
                .h = resistor_width,
            };

            renderer.setColor(resistor_color);
            renderer.drawRect(rect);
            if (name) |str| {
                renderer.renderCenteredText(
                    coords.x + global.grid_size,
                    coords.y - (resistor_width / 2 + global.font_size / 2 + 2),
                    renderer.Color.white,
                    str,
                );
            }

            if (value) |str| {
                renderer.renderCenteredText(
                    coords.x + global.grid_size,
                    coords.y + resistor_width / 2 + global.font_size / 2 + 2,
                    renderer.Color.white,
                    str,
                );
            }
        },
        .bottom, .top => {
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = coords,
                .direction = .vertical,
                .pixel_length = wire_pixel_len,
            }, render_type);
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = renderer.ScreenPosition{
                    .x = coords.x,
                    .y = coords.y + global.grid_size * 2,
                },
                .direction = .vertical,
                .pixel_length = -wire_pixel_len,
            }, render_type);

            const rect = renderer.Rect{
                .x = coords.x - resistor_width / 2,
                .y = coords.y + wire_pixel_len,
                .w = resistor_width,
                .h = resistor_length,
            };

            renderer.setColor(resistor_color);
            renderer.drawRect(rect);
            if (name) |str| {
                renderer.renderCenteredText(
                    coords.x + global.grid_size / 2,
                    coords.y + global.grid_size - (global.font_size / 2 + 8),
                    renderer.Color.white,
                    str,
                );
            }

            if (value) |str| {
                renderer.renderCenteredText(
                    coords.x + global.grid_size / 2,
                    coords.y + global.grid_size + (global.font_size / 2 + 8),
                    renderer.Color.white,
                    str,
                );
            }
        },
    }
}
