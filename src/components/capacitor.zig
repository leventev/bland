const std = @import("std");
const bland = @import("bland");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");
const dvui = @import("dvui");
const GraphicComponent = @import("../component.zig").GraphicComponent;
const VectorRenderer = @import("../VectorRenderer.zig");

const Component = component.Component;
const GridPosition = circuit.GridPosition;
const Rotation = circuit.Rotation;
const Float = bland.Float;

var capacitor_counter: usize = 0;

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

const wire_pixel_len = 55;
const middle_len = 2 * global.grid_size - 2 * wire_pixel_len;

pub fn render(
    circuit_rect: dvui.Rect.Physical,
    grid_pos: GridPosition,
    rot: Rotation,
    name: ?[]const u8,
    value: ?GraphicComponent.ValueBuffer,
    render_type: renderer.ElementRenderType,
) void {
    _ = circuit_rect;
    _ = grid_pos;
    _ = rot;
    _ = name;
    _ = value;
    _ = render_type;
    // const pos = grid_pos.toCircuitPosition(circuit_rect);
    //
    // const capacitor_color = render_type.colors().component_color;
    // const thickness = render_type.thickness();
    //
    // var buff: [256]u8 = undefined;
    // const value_str = if (value) |val|
    //     std.fmt.bufPrint(&buff, "{s}{s}", .{
    //         val.capacitor.actual,
    //         bland.units.Unit.capacitance.symbol(),
    //     }) catch unreachable
    // else
    //     null;
    //
    // switch (rot) {
    //     .left, .right => {
    //         renderer.renderTerminalWire(renderer.TerminalWire{
    //             .pos = pos,
    //             .direction = .horizontal,
    //             .pixel_length = wire_pixel_len,
    //         }, render_type);
    //         renderer.renderTerminalWire(renderer.TerminalWire{
    //             .pos = dvui.Point{
    //                 .x = pos.x + global.grid_size * 2,
    //                 .y = pos.y,
    //             },
    //             .direction = .horizontal,
    //             .pixel_length = -wire_pixel_len,
    //         }, render_type);
    //
    //         renderer.drawLine(
    //             dvui.Point.Physical{
    //                 .x = pos.x + wire_pixel_len,
    //                 .y = pos.y - plate_width / 2,
    //             },
    //             dvui.Point.Physical{
    //                 .x = pos.x + wire_pixel_len,
    //                 .y = pos.y + plate_width / 2,
    //             },
    //             capacitor_color,
    //             thickness,
    //         );
    //
    //         renderer.drawLine(
    //             dvui.Point.Physical{
    //                 .x = pos.x + 2 * global.grid_size - wire_pixel_len,
    //                 .y = pos.y - plate_width / 2,
    //             },
    //             dvui.Point.Physical{
    //                 .x = pos.x + 2 * global.grid_size - wire_pixel_len,
    //                 .y = pos.y + plate_width / 2,
    //             },
    //             capacitor_color,
    //             thickness,
    //         );
    //
    //         if (name) |str| {
    //             renderer.renderCenteredText(
    //                 dvui.Point.Physical{
    //                     .x = pos.x + global.grid_size / 3,
    //                     .y = pos.y - global.grid_size / 4,
    //                 },
    //                 dvui.themeGet().color(.content, .text),
    //                 str,
    //             );
    //         }
    //
    //         if (value_str) |str| {
    //             renderer.renderCenteredText(
    //                 dvui.Point.Physical{
    //                     .x = pos.x + 2 * global.grid_size - global.grid_size / 3,
    //                     .y = pos.y - global.grid_size / 4,
    //                 },
    //                 dvui.themeGet().color(.content, .text),
    //                 str,
    //             );
    //         }
    //     },
    //     .bottom, .top => {
    //         renderer.renderTerminalWire(renderer.TerminalWire{
    //             .pos = pos,
    //             .direction = .vertical,
    //             .pixel_length = wire_pixel_len,
    //         }, render_type);
    //         renderer.renderTerminalWire(renderer.TerminalWire{
    //             .pos = dvui.Point{
    //                 .x = pos.x,
    //                 .y = pos.y + global.grid_size * 2,
    //             },
    //             .direction = .vertical,
    //             .pixel_length = -wire_pixel_len,
    //         }, render_type);
    //
    //         renderer.drawLine(
    //             dvui.Point.Physical{
    //                 .x = pos.x - plate_width / 2,
    //                 .y = pos.y + wire_pixel_len,
    //             },
    //             dvui.Point.Physical{
    //                 .x = pos.x + plate_width / 2,
    //                 .y = pos.y + wire_pixel_len,
    //             },
    //             capacitor_color,
    //             thickness,
    //         );
    //
    //         renderer.drawLine(
    //             dvui.Point.Physical{
    //                 .x = pos.x - plate_width / 2,
    //                 .y = pos.y + 2 * global.grid_size - wire_pixel_len,
    //             },
    //             dvui.Point.Physical{
    //                 .x = pos.x + plate_width / 2,
    //                 .y = pos.y + 2 * global.grid_size - wire_pixel_len,
    //             },
    //             capacitor_color,
    //             thickness,
    //         );
    //
    //         if (name) |str| {
    //             renderer.renderCenteredText(
    //                 dvui.Point.Physical{
    //                     .x = pos.x + global.grid_size / 2,
    //                     .y = pos.y + global.grid_size - (global.circuit_font_size / 2 + 8),
    //                 },
    //                 dvui.themeGet().color(.content, .text),
    //                 str,
    //             );
    //         }
    //
    //         if (value_str) |str| {
    //             renderer.renderCenteredText(
    //                 dvui.Point.Physical{
    //                     .x = pos.x + global.grid_size / 2,
    //                     .y = pos.y + global.grid_size + (global.circuit_font_size / 2 + 8),
    //                 },
    //                 dvui.themeGet().color(.content, .text),
    //                 str,
    //             );
    //         }
    //     },
    // }
}

pub fn renderPropertyBox(
    c: *Float,
    value_buffer: *GraphicComponent.ValueBuffer,
    selected_component_changed: bool,
) void {
    _ = renderer.textEntrySI(
        @src(),
        "capacitance",
        &value_buffer.capacitor.actual,
        .capacitance,
        c,
        selected_component_changed,
        .{},
    );
}

pub fn mouseInside(
    grid_pos: GridPosition,
    rotation: Rotation,
    circuit_rect: dvui.Rect.Physical,
    mouse_pos: dvui.Point.Physical,
) bool {
    _ = grid_pos;
    _ = rotation;
    _ = circuit_rect;
    _ = mouse_pos;
    return false;
    // const pos = grid_pos.toCircuitPosition(circuit_rect);
    //
    // const tolerance = 3;
    //
    // const rect: dvui.Rect.Physical = switch (rotation) {
    //     .left, .right => dvui.Rect.Physical{
    //         .x = pos.x + wire_pixel_len - tolerance,
    //         .y = pos.y - plate_width / 2 - tolerance,
    //         .w = middle_len + 2 * tolerance,
    //         .h = plate_width + 2 * tolerance,
    //     },
    //     .bottom, .top => dvui.Rect.Physical{
    //         .x = pos.x - plate_width / 2 - tolerance,
    //         .y = pos.y + wire_pixel_len - tolerance,
    //         .w = plate_width + 2 * tolerance,
    //         .h = middle_len + 2 * tolerance,
    //     },
    // };
    //
    // return rect.contains(mouse_pos);
}

const total_width = 2.0;
const plate_distance = 0.3;
const plate_width = 0.8;
const wire_len_per_side = (total_width - plate_distance) / 2.0;

pub const bodyInstructions: []const VectorRenderer.BrushInstruction = &.{
    .{ .snap_pixel_set = true },
    .{ .place = .{ .x = wire_len_per_side, .y = -plate_width / 2.0 } },
    .{ .move_rel = .{ .x = 0, .y = plate_width } },
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .place = .{ .x = wire_len_per_side + plate_distance, .y = -plate_width / 2.0 } },
    .{ .move_rel = .{ .x = 0, .y = plate_width } },
    .{ .stroke = .{ .base_thickness = 1 } },
};

pub const terminalWireBrushInstructions: []const VectorRenderer.BrushInstruction = &.{
    .{ .snap_pixel_set = true },
    .{ .move_rel = .{ .x = wire_len_per_side, .y = 0 } },
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .place = .{ .x = wire_len_per_side + plate_distance, .y = 0 } },
    .{ .move_rel = .{ .x = wire_len_per_side, .y = 0 } },
    .{ .stroke = .{ .base_thickness = 1 } },
};
