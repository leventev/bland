const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");

const Component = component.Component;
const Float = bland.Float;

pub const Inner = struct {
    transresistance: Float,
    controller_comp_id: usize,
};

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .ccvs = .{
        .transresistance = 0,
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

    const ccvs_curr_idx = current_group_2_idx orelse @panic("Invalid ccvs stamp");

    // TODO: explain stamping
    mna.stampVoltageCurrent(v_plus, ccvs_curr_idx, 1);
    mna.stampVoltageCurrent(v_minus, ccvs_curr_idx, -1);

    mna.stampCurrentVoltage(ccvs_curr_idx, v_plus, 1);
    mna.stampCurrentVoltage(ccvs_curr_idx, v_minus, -1);
    mna.stampCurrentCurrent(
        ccvs_curr_idx,
        inner.controller_comp_id,
        -inner.transresistance,
    );
}
