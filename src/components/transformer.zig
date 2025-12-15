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

var transformer_counter: usize = 0;

pub fn setNewComponentName(buff: []u8) ![]u8 {
    transformer_counter += 1;
    return std.fmt.bufPrint(buff, "T{}", .{transformer_counter});
}

pub fn getTerminals(
    pos: GridPosition,
    rotation: Rotation,
    terminals: []GridPosition,
) []GridPosition {
    return common.fourTerminalTerminals(pos, rotation, terminals);
}

pub fn getOccupiedGridPositions(
    pos: GridPosition,
    rotation: Rotation,
    occupied: []component.OccupiedGridPosition,
) []component.OccupiedGridPosition {
    return common.fourTerminalOccupiedPoints(pos, rotation, occupied);
}

pub fn centerForMouse(pos: GridPosition, rotation: Rotation) GridPosition {
    return common.fourTerminalCenterForMouse(pos, rotation);
}

pub fn renderPropertyBox(
    turns_ratio: *Float,
    value_buffer: *GraphicComponent.ValueBuffer,
    selected_component_changed: bool,
) void {
    _ = renderer.textEntrySI(
        @src(),
        "turns ratio",
        &value_buffer.transformer.turns_ratio_actual,
        .dimensionless,
        turns_ratio,
        selected_component_changed,
        .{},
    );
}

const total_width = 2.0;
const total_height = 2.0;
const radius = total_height / (4.0 * 2.0);
const wire_len_per_side = 0.5;
const middle_width = total_width - 2.0 * wire_len_per_side - 2.0 * radius;
const line_gap = middle_width / 3.0;
const dot_radius = 0.07;

pub const clickable_shape: GraphicComponent.ClickableShape = .{
    .rect = .{
        .x = wire_len_per_side,
        .y = 0,
        .width = total_width - 2.0 * wire_len_per_side,
        .height = total_height,
    },
};

pub const body_instructions: []const VectorRenderer.BrushInstruction = &.{
    // left circles
    .{ .reset = {} },
    .{ .arc = .{
        .center = .{ .x = wire_len_per_side, .y = radius },
        .radius = radius,
        .start_angle = -std.math.pi / 2.0,
        .sweep_angle = std.math.pi,
    } },
    .{ .arc = .{
        .center = .{ .x = wire_len_per_side, .y = radius + 2 * radius },
        .radius = radius,
        .start_angle = -std.math.pi / 2.0,
        .sweep_angle = std.math.pi,
    } },
    .{ .arc = .{
        .center = .{ .x = wire_len_per_side, .y = radius + 4.0 * radius },
        .radius = radius,
        .start_angle = -std.math.pi / 2.0,
        .sweep_angle = std.math.pi,
    } },
    .{ .arc = .{
        .center = .{ .x = wire_len_per_side, .y = radius + 6.0 * radius },
        .radius = radius,
        .start_angle = -std.math.pi / 2.0,
        .sweep_angle = std.math.pi,
    } },
    .{ .stroke = .{ .base_thickness = 1 } },
    // right circles
    // NOTE: the angles are negative so that the points generated remain continous without jumps
    .{ .reset = {} },
    .{ .arc = .{
        .center = .{ .x = total_width - wire_len_per_side, .y = radius },
        .radius = radius,
        .start_angle = -std.math.pi / 2.0,
        .sweep_angle = -std.math.pi,
    } },
    .{ .arc = .{
        .center = .{ .x = total_width - wire_len_per_side, .y = radius + 2 * radius },
        .radius = radius,
        .start_angle = -std.math.pi / 2.0,
        .sweep_angle = -std.math.pi,
    } },
    .{ .arc = .{
        .center = .{ .x = total_width - wire_len_per_side, .y = radius + 4.0 * radius },
        .radius = radius,
        .start_angle = -std.math.pi / 2.0,
        .sweep_angle = -std.math.pi,
    } },
    .{ .arc = .{
        .center = .{ .x = total_width - wire_len_per_side, .y = radius + 6.0 * radius },
        .radius = radius,
        .start_angle = -std.math.pi / 2.0,
        .sweep_angle = -std.math.pi,
    } },
    // middle lines
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .reset = {} },
    .{ .place = .{ .x = wire_len_per_side + radius + line_gap, .y = 0 } },
    .{ .move_rel = .{ .x = 0, .y = total_height } },
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .reset = {} },
    .{ .place = .{ .x = wire_len_per_side + radius + 2.0 * line_gap, .y = 0 } },
    .{ .move_rel = .{ .x = 0, .y = total_height } },
    .{ .stroke = .{ .base_thickness = 1 } },
    // dots
    .{ .reset = {} },
    .{ .arc = .{
        .center = .{ .x = wire_len_per_side - radius / 2.0, .y = radius },
        .radius = dot_radius,
        .start_angle = 0,
        .sweep_angle = 2 * std.math.pi,
    } },
    .{ .fill = {} },
    .{ .reset = {} },
    .{ .arc = .{
        .center = .{ .x = total_width - wire_len_per_side + radius / 2.0, .y = radius },
        .radius = dot_radius,
        .start_angle = 0,
        .sweep_angle = 2 * std.math.pi,
    } },
    .{ .fill = {} },
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
    .{
        .relative_pos = .{ .x = 0, .y = 2 },
        .direction = .horizontal,
        .len = wire_len_per_side,
    },
    .{
        .relative_pos = .{ .x = 2, .y = 2 },
        .direction = .horizontal,
        .len = -wire_len_per_side,
    },
};
