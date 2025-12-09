const std = @import("std");
const bland = @import("bland");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");
const sidebar = @import("../sidebar.zig");
const dvui = @import("dvui");
const GraphicComponent = @import("../component.zig").GraphicComponent;
const VectorRenderer = @import("../VectorRenderer.zig");

const Component = component.Component;
const GridPosition = circuit.GridPosition;
const Rotation = circuit.Rotation;
const Float = bland.Float;

const cccs_module = bland.component.cccs_module;

var cccs_counter: usize = 0;

pub fn setNewComponentName(buff: []u8) ![]u8 {
    cccs_counter += 1;
    return std.fmt.bufPrint(buff, "CCCS{}", .{cccs_counter});
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
    inner: *cccs_module.Inner,
    value_buffer: *GraphicComponent.ValueBuffer,
    selected_component_changed: bool,
) void {
    _ = renderer.textEntrySI(
        @src(),
        "multiplier",
        &value_buffer.cccs.multiplier_actual,
        .dimensionless,
        &inner.multiplier,
        selected_component_changed,
        .{},
    );

    dvui.label(@src(), "controller name", .{}, .{
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_body,
    });

    var te = dvui.textEntry(@src(), .{
        .text = .{
            .buffer = value_buffer.cccs.controller_name_buff,
        },
    }, .{
        .color_fill = dvui.themeGet().color(.control, .fill),
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_body,
        .expand = .horizontal,
        .margin = dvui.Rect.all(4),
    });

    if (selected_component_changed) {
        te.textSet(value_buffer.cccs.controller_name_actual, false);
    }

    value_buffer.cccs.controller_name_actual = te.getText();
    te.deinit();
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
    //     .left, .right => .{ .x = pos.x + global.grid_size, .y = pos.y },
    //     .top, .bottom => .{ .x = pos.x, .y = pos.y + global.grid_size },
    // };
    //
    // const xd = mouse_pos.x - center.x;
    // const yd = mouse_pos.y - center.y;
    //
    // const check_radius = radius + 3;
    //
    // return xd * xd + yd * yd <= check_radius * check_radius;
}

const total_width = 2.0;
const side_length = 0.4;
const wire_len_per_side = (total_width - 2 * side_length) / 2.0;
const arrow_len = 0.4;
const arrowhead_len = 0.1;

pub const bodyInstructions: []const VectorRenderer.BrushInstruction = &.{
    // diamond
    .{ .place = .{ .x = wire_len_per_side, .y = 0 } },
    .{ .move_rel = .{ .x = side_length, .y = -side_length } },
    .{ .move_rel = .{ .x = side_length, .y = side_length } },
    .{ .move_rel = .{ .x = -side_length, .y = side_length } },
    .{ .move_rel = .{ .x = -side_length, .y = -side_length } },
    .{ .stroke = .{ .base_thickness = 1 } },
    // arrow
    .{ .place = .{ .x = wire_len_per_side + side_length - arrow_len / 2.0, .y = 0 } },
    .{ .move_rel = .{ .x = arrow_len, .y = 0 } },
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .place = .{ .x = wire_len_per_side + side_length + arrow_len / 2.0 - arrowhead_len, .y = -arrowhead_len } },
    .{ .move_rel = .{ .x = arrowhead_len, .y = arrowhead_len } },
    .{ .move_rel = .{ .x = -arrowhead_len, .y = arrowhead_len } },
    .{ .stroke = .{ .base_thickness = 1 } },
};

pub const terminalWireBrushInstructions: []const VectorRenderer.BrushInstruction = &.{
    .{ .snap_pixel_set = true },
    .{ .move_rel = .{ .x = wire_len_per_side, .y = 0 } },
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .place = .{ .x = wire_len_per_side + 2.0 * side_length, .y = 0 } },
    .{ .move_rel = .{ .x = wire_len_per_side, .y = 0 } },
    .{ .stroke = .{ .base_thickness = 1 } },
};
