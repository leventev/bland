const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");
const NetList = @import("../NetList.zig");
const validator = @import("../validator.zig");

const Component = component.Component;
const Float = bland.Float;
const StampOptions = Component.Device.StampOptions;
const StampError = Component.Device.StampError;

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .transformer = 1 };
}

pub fn stampMatrix(
    turns_ratio: Float,
    terminal_node_ids: []const NetList.Node.Id,
    mna: *MNA,
    aux_idx_counter: usize,
    stamp_opts: StampOptions,
) StampError!void {
    const v_primary_plus = terminal_node_ids[0];
    const v_primary_minus = terminal_node_ids[1];
    const v_secondary_plus = terminal_node_ids[3];
    const v_secondary_minus = terminal_node_ids[2];
    _ = v_primary_plus;
    _ = v_primary_minus;
    const curr_idx = aux_idx_counter;
    mna.stampVoltageCurrent(v_secondary_plus, curr_idx, 1);
    mna.stampVoltageCurrent(v_secondary_minus, curr_idx, -1);
    _ = turns_ratio;
    _ = stamp_opts;

    // mna.stampVoltageCurrent(v_plus, curr_idx, 1);
    // mna.stampVoltageCurrent(v_minus, curr_idx, -1);
    //
    // mna.stampCurrentVoltage(curr_idx, v_plus, 1);
    // mna.stampCurrentVoltage(curr_idx, v_minus, -1);
    //
    // switch (voltage) {
    //     .real => |v| mna.stampCurrentRHS(curr_idx, v),
    //     .complex => |v| mna.stampCurrentRHSComplex(curr_idx, v),
    // }
}

pub fn validate(
    resistance: Float,
    _: *const NetList,
    terminal_node_ids: []const NetList.Node.Id,
) validator.ComponentValidationResult {
    return validator.ComponentValidationResult{
        .value_invalid = resistance <= 0,
        .shorted = terminal_node_ids[0] == terminal_node_ids[1],
    };
}
