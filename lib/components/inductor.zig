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
    return Component.Device{ .inductor = 0.001 };
}

pub fn stampMatrix(
    inductance: Float,
    terminal_node_ids: []const NetList.Node.Id,
    mna: *MNA,
    current_group_2_idx: ?NetList.Group2Id,
    stamp_opts: StampOptions,
) StampError!void {
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];
    const curr_idx = current_group_2_idx.?;

    // TODO: explain how stamping works
    switch (stamp_opts) {
        .dc => {
            // short circuit
            mna.stampVoltageCurrent(v_plus, curr_idx, 1);
            mna.stampVoltageCurrent(v_minus, curr_idx, -1);
            mna.stampCurrentVoltage(curr_idx, v_plus, 1);
            mna.stampCurrentVoltage(curr_idx, v_minus, -1);
        },
        .sin_steady_state => |angular_frequency| {
            const z = Complex.init(0, angular_frequency * inductance);
            mna.stampVoltageCurrent(v_plus, curr_idx, 1);
            mna.stampVoltageCurrent(v_minus, curr_idx, -1);
            mna.stampCurrentVoltage(curr_idx, v_plus, 1);
            mna.stampCurrentVoltage(curr_idx, v_minus, -1);
            mna.stampCurrentCurrentComplex(curr_idx, curr_idx, z.neg());
        },
        .transient => |trans| {
            const g = trans.time_step / (2 * inductance);
            const ieq = trans.prev_current.? + g * trans.prev_voltage;

            if (current_group_2_idx) |_| {
                mna.stampVoltageVoltage(v_plus, v_plus, g);
                mna.stampVoltageVoltage(v_plus, v_minus, -g);
                mna.stampVoltageVoltage(v_minus, v_plus, -g);
                mna.stampVoltageVoltage(v_minus, v_minus, g);
                mna.stampVoltageRHS(v_plus, -ieq);
                mna.stampVoltageRHS(v_minus, ieq);
            } else {
                @panic("TODO");
            }
        },
    }
}

pub fn validate(
    inductance: Float,
    _: *const NetList,
    terminal_node_ids: []const NetList.Node.Id,
) validator.ComponentValidationResult {
    return validator.ComponentValidationResult{
        .value_invalid = inductance <= 0,
        .shorted = terminal_node_ids[0] == terminal_node_ids[1],
    };
}
