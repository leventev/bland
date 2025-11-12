const std = @import("std");
const bland = @import("bland.zig");
const MNA = @import("MNA.zig");

const FloatType = bland.Float;

pub const resistor_module = @import("components/resistor.zig");
pub const voltage_source_module = @import("components/voltage_source.zig");
pub const current_source_module = @import("components/current_source.zig");
pub const capacitor_module = @import("components/capacitor.zig");
pub const inductor_module = @import("components/inductor.zig");
pub const ground_module = @import("components/ground.zig");
pub const ccvs_module = @import("components/ccvs.zig");
pub const cccs_module = @import("components/cccs.zig");

pub const max_component_name_length = 20;

pub const Component = struct {
    device: Device,
    terminal_node_ids: []usize,

    name: []const u8,

    pub const DeviceType = enum {
        ground,
        resistor,
        voltage_source,
        current_source,
        capacitor,
        inductor,
        ccvs,
        cccs,

        fn module(comptime self: DeviceType) type {
            return switch (self) {
                .resistor => resistor_module,
                .voltage_source => voltage_source_module,
                .current_source => current_source_module,
                .capacitor => capacitor_module,
                .inductor => inductor_module,
                .ground => ground_module,
                .ccvs => ccvs_module,
                .cccs => cccs_module,
            };
        }

        pub fn defaultValue(self: DeviceType, allocator: std.mem.Allocator) !Device {
            switch (self) {
                inline else => |x| return x.module().defaultValue(allocator),
            }
        }
    };

    pub const Device = union(DeviceType) {
        ground,
        resistor: FloatType,
        voltage_source: FloatType,
        current_source: FloatType,
        capacitor: FloatType,
        inductor: FloatType,
        ccvs: DeviceType.ccvs.module().Inner,
        cccs: DeviceType.cccs.module().Inner,

        pub fn stampMatrix(
            self: *const Device,
            terminal_node_ids: []const usize,
            mna: *MNA,
            current_group_2_idx: ?usize,
            angular_frequency: FloatType,
        ) void {
            switch (@as(DeviceType, self.*)) {
                .ground => {},
                inline else => |x| x.module().stampMatrix(
                    @field(self, @tagName(x)),
                    terminal_node_ids,
                    mna,
                    current_group_2_idx,
                    angular_frequency,
                ),
            }
        }
    };
};
