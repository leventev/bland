const std = @import("std");
const bland = @import("bland.zig");
const MNA = @import("MNA.zig");
const validator = @import("validator.zig");
const NetList = @import("NetList.zig");
pub const source = @import("components/source.zig");

const Float = bland.Float;

pub const resistor_module = @import("components/resistor.zig");
pub const voltage_source_module = @import("components/voltage_source.zig");
pub const current_source_module = @import("components/current_source.zig");
pub const capacitor_module = @import("components/capacitor.zig");
pub const inductor_module = @import("components/inductor.zig");
pub const ccvs_module = @import("components/ccvs.zig");
pub const cccs_module = @import("components/cccs.zig");
pub const diode_module = @import("components/diode.zig");
pub const transformer_module = @import("components/transformer.zig");

pub const max_component_name_length = 20;

pub const Component = struct {
    device: Device,
    terminal_node_ids: []NetList.Node.Id,

    name: []const u8,

    pub const Id = enum(usize) { _ };

    pub fn validate(
        self: *const Component,
        netlist: *const NetList,
    ) validator.ComponentValidationResult {
        return self.device.validate(netlist, self.terminal_node_ids);
    }

    pub const DeviceType = enum {
        resistor,
        voltage_source,
        current_source,
        capacitor,
        inductor,
        ccvs,
        cccs,
        diode,
        transformer,

        fn module(comptime self: DeviceType) type {
            return switch (self) {
                .resistor => resistor_module,
                .voltage_source => voltage_source_module,
                .current_source => current_source_module,
                .capacitor => capacitor_module,
                .inductor => inductor_module,
                .ccvs => ccvs_module,
                .cccs => cccs_module,
                .diode => diode_module,
                .transformer => transformer_module,
            };
        }

        pub fn defaultValue(self: DeviceType, allocator: std.mem.Allocator) !Device {
            switch (self) {
                inline else => |x| return x.module().defaultValue(allocator),
            }
        }
    };

    pub const Device = union(DeviceType) {
        resistor: Float,
        voltage_source: source.OutputFunction,
        current_source: source.OutputFunction,
        capacitor: Float,
        inductor: Float,
        ccvs: ccvs_module.Inner,
        cccs: cccs_module.Inner,
        diode: diode_module.Model,
        transformer: Float,

        pub fn validate(
            self: *const Device,
            netlist: *const bland.NetList,
            terminal_node_ids: []const NetList.Node.Id,
        ) validator.ComponentValidationResult {
            return switch (@as(DeviceType, self.*)) {
                inline else => |x| x.module().validate(
                    @field(self, @tagName(x)),
                    netlist,
                    terminal_node_ids,
                ),
            };
        }
        pub const StampOptions = union(enum) {
            dc: void,
            sin_steady_state: Float,
            transient: struct {
                time: Float,
                time_step: Float,
                prev_voltage: Float,
                prev_current: ?Float,
            },
        };

        pub const StampError = error{
            InvalidOutputFunctionForAnalysisMode,
        };

        pub fn stampMatrix(
            self: *const Device,
            terminal_node_ids: []const NetList.Node.Id,
            mna: *MNA,
            current_group_2_idx: ?NetList.Group2Id,
            stamp_opts: StampOptions,
        ) StampError!void {
            return switch (@as(DeviceType, self.*)) {
                inline else => |x| x.module().stampMatrix(
                    @field(self, @tagName(x)),
                    terminal_node_ids,
                    mna,
                    current_group_2_idx,
                    stamp_opts,
                ),
            };
        }
    };
};
