const std = @import("std");
const NetList = @import("NetList.zig");

pub const ComponentValidationResult = struct {
    value_invalid: bool,
    shorted: bool,
};

pub const ValidationResult = struct {
    comps: []ComponentValidationResult,
};

pub fn validate(gpa: std.mem.Allocator, netlist: *const NetList) !ValidationResult {
    var result = ValidationResult{
        .comps = try gpa.alloc(ComponentValidationResult, netlist.components.items.len),
    };

    for (netlist.components.items, 0..) |comp, i| {
        result.comps[i] = comp.validate(netlist);
    }

    return result;
}
