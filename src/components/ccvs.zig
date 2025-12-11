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

var ccvs_counter: usize = 0;

const ccvs_module = bland.component.ccvs_module;

pub fn setNewComponentName(buff: []u8) ![]u8 {
    ccvs_counter += 1;
    return std.fmt.bufPrint(buff, "CCVS{}", .{ccvs_counter});
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
    inner: *ccvs_module.Inner,
    value_buffer: *GraphicComponent.ValueBuffer,
    selected_component_changed: bool,
) void {
    _ = renderer.textEntrySI(
        @src(),
        "transresistance",
        &value_buffer.ccvs.transresistance_actual,
        .resistance,
        &inner.transresistance,
        selected_component_changed,
        .{},
    );

    dvui.label(@src(), "controller name", .{}, .{
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_body,
    });

    var te = dvui.textEntry(@src(), .{
        .text = .{
            .buffer = value_buffer.ccvs.controller_name_buff,
        },
    }, .{
        .color_fill = dvui.themeGet().color(.control, .fill),
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_body,
        .expand = .horizontal,
        .margin = dvui.Rect.all(4),
    });

    if (selected_component_changed) {
        te.textSet(value_buffer.ccvs.controller_name_actual, false);
    }

    value_buffer.ccvs.controller_name_actual = te.getText();

    te.deinit();
}

pub const clickable_shape: GraphicComponent.ClickableShape = .{
    .circle = .{
        .x = wire_len_per_side + side_length,
        .y = 0,
        .radius = side_length,
    },
};

const total_width = 2.0;
const side_length = 0.4;
const wire_len_per_side = (total_width - 2 * side_length) / 2.0;
const line_len = 0.15;

pub const bodyInstructions: []const VectorRenderer.BrushInstruction = &.{
    // diamond
    .{ .place = .{ .x = wire_len_per_side, .y = 0 } },
    .{ .move_rel = .{ .x = side_length, .y = -side_length } },
    .{ .move_rel = .{ .x = side_length, .y = side_length } },
    .{ .move_rel = .{ .x = -side_length, .y = side_length } },
    .{ .move_rel = .{ .x = -side_length, .y = -side_length } },
    .{ .stroke = .{ .base_thickness = 1 } },
    // plus
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .place = .{ .x = wire_len_per_side + side_length / 2.0 - line_len / 2.0, .y = 0 } },
    .{ .move_rel = .{ .x = line_len, .y = 0 } },
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .place = .{ .x = wire_len_per_side + side_length / 2.0, .y = -line_len / 2.0 } },
    .{ .move_rel = .{ .x = 0, .y = line_len } },
    .{ .stroke = .{ .base_thickness = 1 } },
    // minus
    .{ .place = .{ .x = wire_len_per_side + side_length + side_length / 2.0, .y = -line_len / 2.0 } },
    .{ .move_rel = .{ .x = 0, .y = line_len } },
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
