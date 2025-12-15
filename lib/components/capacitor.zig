const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");
const NetList = @import("../NetList.zig");
const validator = @import("../validator.zig");

const Component = component.Component;
const Float = bland.Float;
const Complex = bland.Complex;
const StampOptions = Component.Device.StampOptions;
const StampError = Component.Device.StampError;

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .capacitor = 0.001 };
}

pub fn stampMatrix(
    c: Float,
    terminal_node_ids: []const NetList.Node.Id,
    mna: *MNA,
    current_group_2_idx: ?NetList.Group2Id,
    stamp_opts: StampOptions,
) StampError!void {
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    // TODO: explain how stamping works
    // in DC analysis a capacitor acts as an open circuit.
    // to achieve this we dont have to do anything
    // by default the two nodes at each terminal are not connected to eachother
    switch (stamp_opts) {
        .dc => {},
        .sin_steady_state => |angular_frequency| {
            const y = Complex.init(0, angular_frequency * c);
            const z = y.reciprocal();
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
        },
        .transient => |trans| {
            // TODO: explain
            // TODO: no current_group_2
            const g = 2 * c / trans.time_step;
            const ieq = trans.prev_current.? + g * trans.prev_voltage;

            if (current_group_2_idx) |_| {
                mna.stampVoltageVoltage(v_plus, v_plus, g);
                mna.stampVoltageVoltage(v_plus, v_minus, -g);
                mna.stampVoltageVoltage(v_minus, v_plus, -g);
                mna.stampVoltageVoltage(v_minus, v_minus, g);
                mna.stampVoltageRHS(v_plus, ieq);
                mna.stampVoltageRHS(v_minus, -ieq);
            } else {
                @panic("TODO");
            }
        },
    }
}

pub fn validate(
    capacitance: Float,
    _: *const NetList,
    terminal_node_ids: []const NetList.Node.Id,
) validator.ComponentValidationResult {
    return validator.ComponentValidationResult{
        .value_invalid = capacitance <= 0,
        .shorted = terminal_node_ids[0] == terminal_node_ids[1],
    };
}
