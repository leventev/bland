const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");

const Component = component.Component;
const Float = bland.Float;

pub fn defaultValue(_: std.mem.Allocator) !Component.Inner {
    return Component.Inner{ .voltage_source = 5 };
}

fn formatValue(value: Float, buf: []u8) !?[]const u8 {
    return try std.fmt.bufPrint(buf, "{d}V", .{value});
}

pub fn stampMatrix(
    v: Float,
    terminal_node_ids: []const usize,
    mna: *MNA,
    current_group_2_idx: ?usize,
    angular_frequency: Float,
) void {
    _ = angular_frequency;

    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    const curr_idx = current_group_2_idx orelse @panic("Invalid voltage stamp");

    // TODO: explain stamping
    mna.stampVoltageCurrent(v_plus, curr_idx, 1);
    mna.stampVoltageCurrent(v_minus, curr_idx, -1);

    mna.stampCurrentVoltage(curr_idx, v_plus, 1);
    mna.stampCurrentVoltage(curr_idx, v_minus, -1);
    mna.stampCurrentRHS(curr_idx, v);
}
