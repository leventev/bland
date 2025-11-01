const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");

const Component = component.Component;
const Float = bland.Float;

pub const Inner = struct {
    controller_name_buff: []u8,
    controller_name: []u8,
    transresistance: Float,

    // set by netlist.analyse
    controller_group_2_idx: ?usize,

    pub fn deinit(self: *Inner, allocator: std.mem.Allocator) void {
        allocator.free(self.controller_name_buff);
        self.controller_name_buff = &.{};
        self.controller_name = &.{};
        self.transresistance = 0;
        self.controller_group_2_idx = null;
    }

    pub fn clone(self: *const Inner, allocator: std.mem.Allocator) !Inner {
        const name_buff = try allocator.dupe(u8, self.controller_name_buff);
        return Inner{
            .controller_name_buff = name_buff,
            .controller_name = name_buff[0..self.controller_name.len],
            .transresistance = self.transresistance,
            .controller_group_2_idx = null,
        };
    }
};

pub fn defaultValue(allocator: std.mem.Allocator) !Component.Device {
    return Component.Device{ .ccvs = .{
        .controller_name_buff = try allocator.alloc(u8, component.max_component_name_length),
        .controller_name = &.{},
        .transresistance = 0,
        .controller_group_2_idx = null,
    } };
}

pub fn formatValue(inner: Inner, buf: []u8) !?[]const u8 {
    return try std.fmt.bufPrint(buf, "{d}*I({s})", .{
        inner.transresistance,
        inner.controller_name,
    });
}

pub fn stampMatrix(
    inner: Inner,
    terminal_node_ids: []const usize,
    mna: *MNA,
    current_group_2_idx: ?usize,
    angular_frequency: Float,
) void {
    _ = angular_frequency;
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    const ccvs_curr_idx = current_group_2_idx orelse @panic("Invalid ccvs stamp");
    const controller_curr_idx = inner.controller_group_2_idx orelse @panic("?");

    // TODO: explain stamping
    mna.stampVoltageCurrent(v_plus, ccvs_curr_idx, 1);
    mna.stampVoltageCurrent(v_minus, ccvs_curr_idx, -1);

    mna.stampCurrentVoltage(ccvs_curr_idx, v_plus, 1);
    mna.stampCurrentVoltage(ccvs_curr_idx, v_minus, -1);
    mna.stampCurrentCurrent(
        ccvs_curr_idx,
        controller_curr_idx,
        -inner.transresistance,
    );
}
