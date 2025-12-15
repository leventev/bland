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
    return Component.Device{ .resistor = 1 };
}

pub fn stampMatrix(
    r: Float,
    terminal_node_ids: []const NetList.Node.Id,
    mna: *MNA,
    aux_idx_counter: usize,
    stamp_opts: StampOptions,
) StampError!void {
    // stamping is the same for every kind of analysis
    _ = stamp_opts;

    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    // TODO: explain how stamping works
    const aux_eq_idx = aux_idx_counter;
    mna.stampVoltageCurrent(v_plus, aux_eq_idx, 1);
    mna.stampVoltageCurrent(v_minus, aux_eq_idx, -1);
    mna.stampCurrentVoltage(aux_eq_idx, v_plus, 1);
    mna.stampCurrentVoltage(aux_eq_idx, v_minus, -1);
    mna.stampCurrentCurrent(aux_eq_idx, aux_eq_idx, -r);
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
