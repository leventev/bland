const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");

const Component = component.Component;
const Float = bland.Float;

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .current_source = 1 };
}

pub fn formatValue(value: Float, buf: []u8) !?[]const u8 {
    return try bland.units.formatUnitBuf(buf, .current, value, 3);
}

pub fn stampMatrix(
    i: Float,
    terminal_node_ids: []const usize,
    mna: *MNA,
    current_group_2_idx: ?usize,
    angular_frequency: Float,
) void {
    _ = angular_frequency;
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    // TODO: explain how stamping works
    if (current_group_2_idx) |curr_idx| {
        mna.stampVoltageCurrent(v_plus, curr_idx, 1);
        mna.stampVoltageCurrent(v_minus, curr_idx, -1);
        mna.stampCurrentCurrent(curr_idx, curr_idx, 1);
        mna.stampCurrentRHS(curr_idx, i);
    } else {
        mna.stampVoltageRHS(v_plus, -i);
        mna.stampVoltageRHS(v_minus, i);
    }
}
