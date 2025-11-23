const std = @import("std");
const bland = @import("bland");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");
const dvui = @import("dvui");
const GraphicComponent = @import("../component.zig").GraphicComponent;

const Component = component.Component;
const GridPosition = circuit.GridPosition;
const Rotation = circuit.Rotation;
const Float = bland.Float;

const diode_module = bland.component.diode_module;

var diode_counter: usize = 0;

pub fn setNewComponentName(buff: []u8) ![]u8 {
    diode_counter += 1;
    return std.fmt.bufPrint(buff, "D{}", .{diode_counter});
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
    value: ?GraphicComponent.ValueBuffer,
    render_type: renderer.ComponentRenderType,
) void {
    _ = value;

    const diode_width = 40;
    const diode_length = 40;

    const wire_pixel_len = global.grid_size - diode_length / 2;

    const pos = grid_pos.toCircuitPosition(circuit_rect);

    const diode_color = render_type.colors().component_color;
    const thickness = render_type.thickness();

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

            var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());
            defer path.deinit();

            // TODO: both sides
            path.addPoint(dvui.Point.Physical{ .x = pos.x + wire_pixel_len + diode_length, .y = pos.y - diode_width / 2 });
            path.addPoint(dvui.Point.Physical{ .x = pos.x + wire_pixel_len + diode_length, .y = pos.y });
            path.addPoint(dvui.Point.Physical{ .x = pos.x + wire_pixel_len, .y = pos.y - diode_width / 2 });
            path.addPoint(dvui.Point.Physical{ .x = pos.x + wire_pixel_len, .y = pos.y + diode_width / 2 });
            path.addPoint(dvui.Point.Physical{ .x = pos.x + wire_pixel_len + diode_length, .y = pos.y });
            path.addPoint(dvui.Point.Physical{ .x = pos.x + wire_pixel_len + diode_length, .y = pos.y + diode_width / 2 });

            path.build().stroke(.{ .color = diode_color, .thickness = thickness });

            if (name) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + global.grid_size,
                        .y = pos.y - (diode_width / 2 + global.circuit_font_size / 2 + 2),
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

            var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());
            defer path.deinit();

            // TODO: both sides
            path.addPoint(dvui.Point.Physical{ .x = pos.x - diode_width / 2, .y = pos.y + wire_pixel_len + diode_length });
            path.addPoint(dvui.Point.Physical{ .x = pos.x, .y = pos.y + wire_pixel_len + diode_length });
            path.addPoint(dvui.Point.Physical{ .x = pos.x - diode_width / 2, .y = pos.y + wire_pixel_len });
            path.addPoint(dvui.Point.Physical{ .x = pos.x + diode_width / 2, .y = pos.y + wire_pixel_len });
            path.addPoint(dvui.Point.Physical{ .x = pos.x, .y = pos.y + wire_pixel_len + diode_length });
            path.addPoint(dvui.Point.Physical{ .x = pos.x + diode_width / 2, .y = pos.y + wire_pixel_len + diode_length });

            path.build().stroke(.{ .color = diode_color, .thickness = thickness });

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
        },
    }
}

pub fn renderPropertyBox(model: *diode_module.Model, value_buffer: *GraphicComponent.ValueBuffer, selected_component_changed: bool) void {
    _ = model;
    _ = value_buffer;
    _ = selected_component_changed;
}
