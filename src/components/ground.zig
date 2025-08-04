const std = @import("std");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");

const Component = component.Component;
const GridPosition = circuit.GridPosition;
const OccupiedGridPosition = component.OccupiedGridPosition;

var ground_counter: usize = 0;

pub fn defaultValue() Component.Inner {
    return Component.Inner{ .ground = {} };
}

pub fn formatValue(value: u32, buf: []u8) !?[]const u8 {
    _ = value;
    _ = buf;
    return null;
}

pub fn setNewComponentName(buff: []u8) ![]u8 {
    ground_counter += 1;
    return std.fmt.bufPrint(buff, "G{}", .{ground_counter});
}

pub fn getTerminals(
    pos: GridPosition,
    rotation: Component.Rotation,
    terminals: []GridPosition,
) []GridPosition {
    _ = rotation;
    terminals[0] = GridPosition{
        .x = pos.x,
        .y = pos.y,
    };
    return terminals[0..1];
}

pub fn getOccupiedGridPositions(
    pos: GridPosition,
    rotation: Component.Rotation,
    occupied: []OccupiedGridPosition,
) []OccupiedGridPosition {
    occupied[0] = OccupiedGridPosition{
        .pos = GridPosition{ .x = pos.x, .y = pos.y },
        .terminal = true,
    };
    switch (rotation) {
        .left => {
            occupied[1] = OccupiedGridPosition{
                .pos = GridPosition{ .x = pos.x - 1, .y = pos.y },
                .terminal = false,
            };
        },
        .right => {
            occupied[1] = OccupiedGridPosition{
                .pos = GridPosition{ .x = pos.x + 1, .y = pos.y },
                .terminal = false,
            };
        },
        .top => {
            occupied[1] = OccupiedGridPosition{
                .pos = GridPosition{ .x = pos.x, .y = pos.y - 1 },
                .terminal = false,
            };
        },
        .bottom => {
            occupied[1] = OccupiedGridPosition{
                .pos = GridPosition{ .x = pos.x, .y = pos.y + 1 },
                .terminal = false,
            };
        },
    }
    return occupied[0..2];
}

pub fn render(
    pos: GridPosition,
    rot: Component.Rotation,
    render_type: renderer.ComponentRenderType,
) void {
    const wire_pixel_len = 16;

    const world_pos = renderer.WorldPosition.fromGridPosition(pos);
    const coords = renderer.ScreenPosition.fromWorldPosition(world_pos);

    const render_colors = renderer.renderColors(render_type);

    const triangle_side = 45;
    const triangle_height = 39;

    switch (rot) {
        .right, .left => {
            const wire_off: i32 = if (rot == .right) wire_pixel_len else -wire_pixel_len;
            renderer.renderTerminalWire(renderer.TerminalWire{
                .direction = .horizontal,
                .pos = coords,
                .pixel_length = wire_off,
            }, render_type);

            const x_off: i32 = if (rot == .right) triangle_height else -triangle_height;

            renderer.setColor(render_colors.component_color);
            renderer.drawLine(
                coords.x + wire_off,
                coords.y - triangle_side / 2,
                coords.x + wire_off,
                coords.y + triangle_side / 2,
            );

            renderer.drawLine(
                coords.x + wire_off,
                coords.y - triangle_side / 2,
                coords.x + wire_off + x_off,
                coords.y,
            );

            renderer.drawLine(
                coords.x + wire_off,
                coords.y + triangle_side / 2,
                coords.x + wire_off + x_off,
                coords.y,
            );
        },
        .top, .bottom => {
            const wire_off: i32 = if (rot == .bottom) wire_pixel_len else -wire_pixel_len;
            renderer.renderTerminalWire(renderer.TerminalWire{
                .direction = .vertical,
                .pos = coords,
                .pixel_length = wire_off,
            }, render_type);

            const y_off: i32 = if (rot == .bottom) triangle_height else -triangle_height;

            renderer.setColor(render_colors.component_color);
            renderer.drawLine(
                coords.x - triangle_side / 2,
                coords.y + wire_off,
                coords.x + triangle_side / 2,
                coords.y + wire_off,
            );

            renderer.drawLine(
                coords.x - triangle_side / 2,
                coords.y + wire_off,
                coords.x,
                coords.y + wire_off + y_off,
            );

            renderer.drawLine(
                coords.x + triangle_side / 2,
                coords.y + wire_off,
                coords.x,
                coords.y + wire_off + y_off,
            );
        },
    }
}
