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

pub fn formatValue(value: Float, buf: []u8) !?[]const u8 {
    return try bland.units.formatUnitBuf(buf, .resistance, value, 3);
}

pub fn stampMatrix(
    r: Float,
    terminal_node_ids: []const NetList.Node.Id,
    mna: *MNA,
    current_group_2_idx: ?NetList.Group2Id,
    stamp_opts: StampOptions,
) StampError!void {
    // stamping is the same for every kind of analysis
    _ = stamp_opts;

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
