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
const OccupiedGridPosition = component.OccupiedGridPosition;
const Rotation = circuit.Rotation;

const Float = bland.Float;

var ground_counter: usize = 0;

pub fn defaultValue(_: std.mem.Allocator) !Component.Inner {
    return Component.Inner{ .ground = {} };
}

pub fn setNewComponentName(buff: []u8) ![]u8 {
    ground_counter += 1;
    return std.fmt.bufPrint(buff, "G{}", .{ground_counter});
}

pub fn centerForMouse(pos: GridPosition, rotation: Rotation) GridPosition {
    _ = rotation;
    return pos;
}

pub fn getTerminals(
    pos: GridPosition,
    rotation: Rotation,
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
    rotation: Rotation,
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
    circuit_area: dvui.Rect.Physical,
    grid_pos: GridPosition,
    rot: Rotation,
    render_type: renderer.ComponentRenderType,
) void {
    const pos = grid_pos.toCircuitPosition(circuit_area);
    const render_colors = render_type.colors();
    const thickness = render_type.thickness();

    const triangle_side = 45;
    const triangle_height = 39;
    const wire_pixel_len = 16;

    switch (rot) {
        .right, .left => {
            const wire_off: f32 = if (rot == .right) wire_pixel_len else -wire_pixel_len;
            renderer.renderTerminalWire(renderer.TerminalWire{
                .direction = .horizontal,
                .pos = pos,
                .pixel_length = wire_off,
            }, render_type);

            const x_off: f32 = if (rot == .right) triangle_height else -triangle_height;

            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x + wire_off,
                    .y = pos.y - triangle_side / 2,
                },
                dvui.Point.Physical{
                    .x = pos.x + wire_off,
                    .y = pos.y + triangle_side / 2,
                },
                render_colors.component_color,
                thickness,
            );

            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x + wire_off,
                    .y = pos.y - triangle_side / 2,
                },
                dvui.Point.Physical{
                    .x = pos.x + wire_off + x_off,
                    .y = pos.y,
                },
                render_colors.component_color,
                thickness,
            );

            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x + wire_off,
                    .y = pos.y + triangle_side / 2,
                },
                dvui.Point.Physical{
                    .x = pos.x + wire_off + x_off,
                    .y = pos.y,
                },
                render_colors.component_color,
                thickness,
            );
        },
        .top, .bottom => {
            const wire_off: f32 = if (rot == .bottom) wire_pixel_len else -wire_pixel_len;
            renderer.renderTerminalWire(renderer.TerminalWire{
                .direction = .vertical,
                .pos = pos,
                .pixel_length = wire_off,
            }, render_type);

            const y_off: f32 = if (rot == .bottom) triangle_height else -triangle_height;

            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x - triangle_side / 2,
                    .y = pos.y + wire_off,
                },
                dvui.Point.Physical{
                    .x = pos.x + triangle_side / 2,
                    .y = pos.y + wire_off,
                },
                render_colors.component_color,
                thickness,
            );

            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x - triangle_side / 2,
                    .y = pos.y + wire_off,
                },
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + wire_off + y_off,
                },
                render_colors.component_color,
                thickness,
            );

            renderer.drawLine(
                dvui.Point.Physical{
                    .x = pos.x + triangle_side / 2,
                    .y = pos.y + wire_off,
                },
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + wire_off + y_off,
                },
                render_colors.component_color,
                thickness,
            );
        },
    }
}
