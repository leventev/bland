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
    transresistance: Float,
    controller_comp_id: Component.Id,
};

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{
        .ccvs = .{
            .transresistance = 0,
            .controller_comp_id = @enumFromInt(0),
        },
    };
}

pub fn stampMatrix(
    inner: Inner,
    terminal_node_ids: []const NetList.Node.Id,
    mna: *MNA,
    current_group_2_idx: ?NetList.Group2Id,
    stamp_opts: StampOptions,
) StampError!void {
    // stamping is the same for every kind of analysis
    _ = stamp_opts;

    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    const ccvs_curr_idx = current_group_2_idx orelse @panic("Invalid ccvs stamp");

    const controller_curr_id: NetList.Group2Id = @enumFromInt(std.mem.indexOfScalar(
        Component.Id,
        mna.group_2,
        inner.controller_comp_id,
    ) orelse unreachable);

    // TODO: explain stamping
    mna.stampVoltageCurrent(v_plus, ccvs_curr_idx, 1);
    mna.stampVoltageCurrent(v_minus, ccvs_curr_idx, -1);

    mna.stampCurrentVoltage(ccvs_curr_idx, v_plus, 1);
    mna.stampCurrentVoltage(ccvs_curr_idx, v_minus, -1);
    mna.stampCurrentCurrent(
        ccvs_curr_idx,
        controller_curr_id,
        -inner.transresistance,
    );
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
