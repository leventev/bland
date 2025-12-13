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

const total_width = 2.0;
const diode_side_len = 0.4;
const diode_length = 0.7;
const wire_len_per_side = (total_width - diode_length) / 2.0;

pub const clickable_shape: GraphicComponent.ClickableShape = .{
    .rect = .{
        .x = wire_len_per_side,
        .y = -diode_side_len,
        .width = diode_length,
        .height = 2 * diode_side_len,
    },
};

pub const body_instructions: []const VectorRenderer.BrushInstruction = &.{
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

pub const terminal_wires: []const GraphicComponent.Terminal = &.{
    .{
        .relative_pos = .{ .x = 0, .y = 0 },
        .direction = .horizontal,
        .len = wire_len_per_side,
    },
    .{
        .relative_pos = .{ .x = 2, .y = 0 },
        .direction = .horizontal,
        .len = -wire_len_per_side,
    },
};
