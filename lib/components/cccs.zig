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

pub const Inner = struct {
    multiplier: Float,
    controller_comp_id: Component.Id,
};

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .cccs = .{
        .multiplier = 0,
        .controller_comp_id = @enumFromInt(0),
    } };
}

pub fn stampMatrix(
    inner: Inner,
    terminal_node_ids: []const NetList.Node.Id,
    mna: *MNA,
    aux_idx_counter: usize,
    stamp_opts: StampOptions,
) StampError!void {
    // stamping is the same for every kind of analysis
    _ = stamp_opts;
    _ = inner;
    _ = terminal_node_ids;
    _ = mna;
    _ = aux_idx_counter;
    @panic("TODO");

    // const v_plus = terminal_node_ids[0];
    // const v_minus = terminal_node_ids[1];
    // // TODO: explain stamping
    // const aux_eq_idx = aux_idx_counter;
    // mna.stampVoltageCurrent(v_plus, aux_eq_idx, 1);
    // mna.stampVoltageCurrent(v_minus, aux_eq_idx, -1);
    // mna.stampCurrentCurrent(aux_eq_idx, aux_eq_idx, 1);
    // mna.stampCurrentCurrent(aux_eq_idx, controller_curr_id, -inner.multiplier);
}

pub fn validate(
    value: Inner,
    netlist: *const NetList,
    terminal_node_ids: []const NetList.Node.Id,
) validator.ComponentValidationResult {
    return validator.ComponentValidationResult{
        .value_invalid = netlist.components.items.len <= @intFromEnum(value.controller_comp_id),
        .shorted = terminal_node_ids[0] == terminal_node_ids[1],
    };
}
