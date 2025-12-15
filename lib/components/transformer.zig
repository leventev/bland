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
    current_group_2_idx: ?NetList.Group2Id,
    stamp_opts: StampOptions,
) StampError!void {
    _ = turns_ratio;
    _ = terminal_node_ids;
    _ = mna;
    _ = current_group_2_idx;
    _ = stamp_opts;
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
