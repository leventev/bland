const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");
const source = @import("source.zig");
const NetList = @import("../NetList.zig");
const validator = @import("../validator.zig");

const Component = component.Component;
const Float = bland.Float;
const Complex = bland.Complex;
const StampOptions = Component.Device.StampOptions;
const StampError = Component.Device.StampError;

pub const ModelType = enum {
    ideal,
};

pub const Model = union(ModelType) {
    ideal: void,
};

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .diode = .{ .ideal = {} } };
}

pub fn stampMatrix(
    model: Model,
    terminal_node_ids: []const NetList.Node.Id,
    mna: *MNA,
    current_group_2_idx: ?NetList.Group2Id,
    stamp_opts: StampOptions,
) StampError!void {
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    _ = model;
    _ = mna;
    _ = current_group_2_idx;
    _ = stamp_opts;
    _ = v_plus;
    _ = v_minus;
}

pub fn validate(
    model: Model,
    _: *const NetList,
    terminal_node_ids: []const NetList.Node.Id,
) validator.ComponentValidationResult {
    _ = model;
    return validator.ComponentValidationResult{
        .value_invalid = false,
        .shorted = terminal_node_ids[0] == terminal_node_ids[1],
    };
}
