const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");

const Component = component.Component;
const Float = bland.Float;
const Complex = bland.Complex;

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .inductor = 0.001 };
}

pub fn formatValue(value: Float, buf: []u8) !?[]const u8 {
    return try std.fmt.bufPrint(buf, "{d}H", .{value});
}

pub fn stampMatrix(
    inductance: Float,
    terminal_node_ids: []const usize,
    mna: *MNA,
    current_group_2_idx: ?usize,
    angular_frequency: Float,
) void {
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    const z = Complex.init(0, angular_frequency * inductance);

    const curr_idx = current_group_2_idx.?;

    if (angular_frequency == 0) {
        // TODO
    } else {
        // TODO: explain how stamping works
        mna.stampVoltageCurrent(v_plus, curr_idx, 1);
        mna.stampVoltageCurrent(v_minus, curr_idx, -1);
        mna.stampCurrentVoltage(curr_idx, v_plus, 1);
        mna.stampCurrentVoltage(curr_idx, v_minus, -1);
        mna.stampCurrentCurrentComplex(curr_idx, curr_idx, z.neg());
    }
}
