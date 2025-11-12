const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");

const Component = component.Component;
const Float = bland.Float;

pub const Inner = struct {
    multiplier: Float,
    controller_comp_id: usize,
};

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .cccs = .{
        .multiplier = 0,
        .controller_comp_id = 0,
    } };
}

pub fn stampMatrix(
    inner: Inner,
    terminal_node_ids: []const usize,
    mna: *MNA,
    current_group_2_idx: ?usize,
    angular_frequency: Float,
) void {
    _ = angular_frequency;

    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];
    // TODO: explain stamping
    if (current_group_2_idx) |curr_idx| {
        mna.stampVoltageCurrent(v_plus, curr_idx, 1);
        mna.stampVoltageCurrent(v_minus, curr_idx, -1);
        mna.stampCurrentCurrent(curr_idx, curr_idx, 1);
        mna.stampCurrentCurrent(curr_idx, inner.controller_comp_id, -inner.multiplier);
    } else {
        mna.stampVoltageCurrent(v_plus, inner.controller_comp_id, -inner.multiplier);
        mna.stampVoltageCurrent(v_minus, inner.controller_comp_id, inner.multiplier);
    }
}
