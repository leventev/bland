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

const total_width = 2.0;
const side_length = 0.4;
const wire_len_per_side = (total_width - 2 * side_length) / 2.0;
const arrow_len = 0.4;
const arrowhead_len = 0.1;

pub const clickable_shape: GraphicComponent.ClickableShape = .{
    .circle = .{
        .x = wire_len_per_side + side_length,
        .y = 0,
        .radius = side_length,
    },
};

pub const body_instructions: []const VectorRenderer.BrushInstruction = &.{
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
