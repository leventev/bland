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

var inductor_counter: usize = 0;

pub fn setNewComponentName(buff: []u8) ![]u8 {
    inductor_counter += 1;
    return std.fmt.bufPrint(buff, "L{}", .{inductor_counter});
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

pub fn renderPropertyBox(
    l: *Float,
    value_buffer: *GraphicComponent.ValueBuffer,
    selected_component_changed: bool,
) void {
    _ = renderer.textEntrySI(
        @src(),
        "inductance",
        &value_buffer.inductor.actual,
        .inductance,
        l,
        selected_component_changed,
        .{},
    );
}

const total_width = 2.0;
const radius = 0.15;
const wire_len_per_side = (total_width - 4 * 2 * radius) / 2.0;

pub const clickable_shape: GraphicComponent.ClickableShape = .{
    .rect = .{
        .x = wire_len_per_side,
        .y = -radius,
        .width = 8 * radius,
        .height = radius,
    },
};

pub const bodyInstructions: []const VectorRenderer.BrushInstruction = &.{
    .{ .reset = {} },
    .{ .arc = .{
        .center = .{ .x = wire_len_per_side + radius, .y = 0 },
        .radius = radius,
        .start_angle = -std.math.pi,
        .sweep_angle = std.math.pi,
    } },
    .{ .arc = .{
        .center = .{ .x = wire_len_per_side + radius + 2.0 * radius, .y = 0 },
        .radius = radius,
        .start_angle = -std.math.pi,
        .sweep_angle = std.math.pi,
    } },
    .{ .arc = .{
        .center = .{ .x = wire_len_per_side + radius + 4.0 * radius, .y = 0 },
        .radius = radius,
        .start_angle = -std.math.pi,
        .sweep_angle = std.math.pi,
    } },
    .{ .arc = .{
        .center = .{ .x = wire_len_per_side + radius + 6.0 * radius, .y = 0 },
        .radius = radius,
        .start_angle = -std.math.pi,
        .sweep_angle = std.math.pi,
    } },
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
