const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");

const Component = component.Component;
const Float = bland.Float;
const Complex = bland.Complex;

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .capacitor = 0.001 };
}

pub fn formatValue(value: Float, buf: []u8) !?[]const u8 {
    return try bland.units.formatUnitBuf(buf, .capacitance, value, 3);
}

pub fn stampMatrix(
    c: Float,
    terminal_node_ids: []const usize,
    mna: *MNA,
    current_group_2_idx: ?usize,
    angular_frequency: Float,
) void {
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    const y = Complex.init(0, angular_frequency * c);
    const z = y.reciprocal();

    if (angular_frequency != 0) {
        // TODO: explain how stamping works
        if (current_group_2_idx) |curr_idx| {
            mna.stampVoltageCurrent(v_plus, curr_idx, 1);
            mna.stampVoltageCurrent(v_minus, curr_idx, -1);
            mna.stampCurrentVoltage(curr_idx, v_plus, 1);
            mna.stampCurrentVoltage(curr_idx, v_minus, -1);
            mna.stampCurrentCurrentComplex(curr_idx, curr_idx, z.neg());
        } else {
            mna.stampVoltageVoltageComplex(v_plus, v_plus, y);
            mna.stampVoltageVoltageComplex(v_plus, v_minus, y.neg());
            mna.stampVoltageVoltageComplex(v_minus, v_plus, y.neg());
            mna.stampVoltageVoltageComplex(v_minus, v_minus, y);
        }
    } else {
        // if angular frequency is 0 then we are doing DC analysis
        // and in DC analysis a capacitor acts as an open circuit.
        // to achieve this we dont have to do anything
        // by default the two nodes at each terminal are not connected to eachother
    }
}
