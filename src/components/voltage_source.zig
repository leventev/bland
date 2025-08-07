const std = @import("std");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");

const Component = component.Component;
const GridPosition = circuit.GridPosition;

var voltage_source_counter: usize = 0;

pub fn defaultValue() Component.Inner {
    return Component.Inner{ .voltage_source = 5 };
}
pub fn setNewComponentName(buff: []u8) ![]u8 {
    voltage_source_counter += 1;
    return std.fmt.bufPrint(buff, "V{}", .{voltage_source_counter});
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
    return try std.fmt.bufPrint(buf, "{d}V", .{value});
}

pub fn render(
    pos: GridPosition,
    rot: component.Component.Rotation,
    name: ?[]const u8,
    value: ?f32,
    render_type: renderer.ComponentRenderType,
) void {
    const world_pos = renderer.WorldPosition.fromGridPosition(pos);
    const coords = renderer.ScreenPosition.fromWorldPosition(world_pos);

    const total_len = 2 * global.grid_size;
    const middle_len = 16;
    const middle_width = 4;
    const wire_len = (total_len - middle_len) / 2;

    const positive_side_len = 48;
    const negative_side_len = 32;

    const render_colors = renderer.renderColors(render_type);

    var buff: [256]u8 = undefined;
    const value_str = if (value) |val| formatValue(
        val,
        buff[0..],
    ) catch unreachable else null;

    switch (rot) {
        .left, .right => {
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = coords,
                .direction = .horizontal,
                .pixel_length = wire_len,
            }, render_type);
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = renderer.ScreenPosition{
                    .x = coords.x + global.grid_size * 2,
                    .y = coords.y,
                },
                .direction = .horizontal,
                .pixel_length = -wire_len,
            }, render_type);

            var rect1 = renderer.Rect{
                .x = coords.x + wire_len,
                .y = coords.y - positive_side_len / 2,
                .w = middle_width,
                .h = positive_side_len,
            };
            var rect2 = renderer.Rect{
                .x = coords.x + wire_len + middle_len - middle_width,
                .y = coords.y - negative_side_len / 2,
                .w = middle_width,
                .h = negative_side_len,
            };

            if (rot == .left) {
                const tmp = rect1.x;
                rect1.x = rect2.x;
                rect2.x = tmp;
            }

            renderer.setColor(render_colors.component_color);
            renderer.drawRect(rect1);
            renderer.drawRect(rect2);

            if (name) |str| {
                renderer.renderCenteredText(
                    coords.x + global.grid_size / 2,
                    coords.y - global.grid_size / 4,
                    renderer.Color.white,
                    str,
                );
            }

            if (value_str) |str| {
                renderer.renderCenteredText(
                    coords.x + global.grid_size + global.grid_size / 2,
                    coords.y - global.grid_size / 4,
                    renderer.Color.white,
                    str,
                );
            }

            const sign: i32 = if (rot == .right) -1 else 1;
            renderer.renderCenteredText(coords.x + global.grid_size + sign * 20, coords.y + global.grid_size / 4, render_colors.component_color, "+");
            renderer.renderCenteredText(coords.x + global.grid_size - sign * 20, coords.y + global.grid_size / 4, render_colors.component_color, "-");
        },
        .top, .bottom => {
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = coords,
                .direction = .vertical,
                .pixel_length = wire_len,
            }, render_type);
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = renderer.ScreenPosition{
                    .x = coords.x,
                    .y = coords.y + global.grid_size * 2,
                },
                .direction = .vertical,
                .pixel_length = -wire_len,
            }, render_type);

            var rect1 = renderer.Rect{
                .x = coords.x - positive_side_len / 2,
                .y = coords.y + wire_len,
                .w = positive_side_len,
                .h = middle_width,
            };
            var rect2 = renderer.Rect{
                .x = coords.x - negative_side_len / 2,
                .y = coords.y + wire_len + middle_len - middle_width,
                .w = negative_side_len,
                .h = middle_width,
            };

            if (rot == .top) {
                const tmp = rect1.y;
                rect1.y = rect2.y;
                rect2.y = tmp;
            }

            renderer.setColor(render_colors.component_color);
            renderer.drawRect(rect1);
            renderer.drawRect(rect2);
            if (name) |str| {
                renderer.renderCenteredText(
                    coords.x + global.grid_size / 2,
                    coords.y + global.grid_size - (global.font_size + 2),
                    renderer.Color.white,
                    str,
                );
            }

            if (value_str) |str| {
                renderer.renderCenteredText(
                    coords.x + global.grid_size / 2,
                    coords.y + global.grid_size + (global.font_size + 2),
                    renderer.Color.white,
                    str,
                );
            }

            const sign: i32 = if (rot == .bottom) -1 else 1;
            renderer.renderCenteredText(coords.x - global.grid_size / 4, coords.y + global.grid_size + sign * 20, render_colors.component_color, "+");
            renderer.renderCenteredText(coords.x - global.grid_size / 4, coords.y + global.grid_size - sign * 20, render_colors.component_color, "-");
        },
    }
}
