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

pub fn renderPropertyBox(model: *diode_module.Model, value_buffer: *GraphicComponent.ValueBuffer, selected_component_changed: bool) void {
    _ = model;
    _ = value_buffer;
    _ = selected_component_changed;
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
    // const center: dvui.Point.Physical = switch (rotation) {
    //     .left, .right => .{ .x = pos.x + wire_pixel_len + diode_length / 2, .y = pos.y },
    //     .top, .bottom => .{ .x = pos.x, .y = pos.y + wire_pixel_len + diode_length / 2 },
    // };
    //
    // const xd = mouse_pos.x - center.x;
    // const yd = mouse_pos.y - center.y;
    //
    // const tolerance = 6;
    // const check_radius = diode_length / 2 + tolerance;
    //
    // return xd * xd + yd * yd <= check_radius * check_radius;
}

const total_width = 2.0;
const diode_side_len = 0.4;
const diode_length = 0.7;
const wire_len_per_side = (total_width - diode_length) / 2.0;

pub const bodyInstructions: []const VectorRenderer.BrushInstruction = &.{
    .{ .snap_pixel_set = true },
    .{ .place = .{ .x = wire_len_per_side, .y = 0 } },
    .{ .move_rel = .{ .x = 0, .y = diode_side_len } },
    .{ .move_rel = .{ .x = diode_length, .y = -diode_side_len } },
    .{ .move_rel = .{ .x = -diode_length, .y = 0 } },
    .{ .move_rel = .{ .x = 0, .y = -diode_side_len } },
    .{ .move_rel = .{ .x = diode_length, .y = diode_side_len } },
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .place = .{ .x = wire_len_per_side + diode_length, .y = -diode_side_len } },
    .{ .move_rel = .{ .x = 0, .y = 2 * diode_side_len } },
    .{ .stroke = .{ .base_thickness = 1 } },
};

pub const terminalWireBrushInstructions: []const VectorRenderer.BrushInstruction = &.{
    .{ .snap_pixel_set = true },
    .{ .move_rel = .{ .x = wire_len_per_side, .y = 0 } },
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .place = .{ .x = total_width - wire_len_per_side, .y = 0 } },
    .{ .move_rel = .{ .x = wire_len_per_side, .y = 0 } },
    .{ .stroke = .{ .base_thickness = 1 } },
};
