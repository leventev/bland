const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");

const Component = component.Component;
const Float = bland.Float;

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .resistor = 1 };
}

pub fn formatValue(value: Float, buf: []u8) !?[]const u8 {
    return try std.fmt.bufPrint(buf, "{d}{s}", .{
        value,
        bland.units.Unit.resistance.symbol(),
    });
}

pub fn stampMatrix(
    r: Float,
    terminal_node_ids: []const usize,
    mna: *MNA,
    current_group_2_idx: ?usize,
    angular_frequency: Float,
) void {
    _ = angular_frequency;
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    const g = 1 / r;

    // TODO: explain how stamping works
    if (current_group_2_idx) |curr_idx| {
        mna.stampVoltageCurrent(v_plus, curr_idx, 1);
        mna.stampVoltageCurrent(v_minus, curr_idx, -1);
        mna.stampCurrentVoltage(curr_idx, v_plus, 1);
        mna.stampCurrentVoltage(curr_idx, v_minus, -1);
        mna.stampCurrentCurrent(curr_idx, curr_idx, -r);
    } else {
        mna.stampVoltageVoltage(v_plus, v_plus, g);
        mna.stampVoltageVoltage(v_plus, v_minus, -g);
        mna.stampVoltageVoltage(v_minus, v_plus, -g);
        mna.stampVoltageVoltage(v_minus, v_minus, g);
    }
}
