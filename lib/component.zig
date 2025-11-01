const std = @import("std");
const bland = @import("bland.zig");
const MNA = @import("MNA.zig");

const FloatType = bland.Float;

pub const Component = struct {
    device: Device,
    terminal_node_ids: []usize,

    // name_buffer is max_component_name_length bytes long allocated
    // name is either a slice into name_buffer or copied when creating a netlist
    // when cloned => name_buffer == name
    name_buffer: []u8,
    name: []u8,

    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        self.device.deinit(allocator);
        self.* = undefined;
    }

    pub const DeviceType = enum {
        ground,
        resistor,
        voltage_source,
        current_source,
        capacitor,
        ccvs,
        cccs,

        fn module(comptime self: DeviceType) type {
            return switch (self) {
                .resistor => @import("components/resistor.zig"),
                .voltage_source => @import("components/voltage_source.zig"),
                .current_source => @import("components/current_source.zig"),
                .capacitor => @import("components/capacitor.zig"),
                .ground => @import("components/ground.zig"),
                .ccvs => @import("components/ccvs.zig"),
                .cccs => @import("components/cccs.zig"),
            };
        }
    };

    pub const Device = union(DeviceType) {
        ground,
        resistor: FloatType,
        voltage_source: FloatType,
        current_source: FloatType,
        capacitor: FloatType,
        ccvs: DeviceType.ccvs.module().Inner,
        cccs: DeviceType.cccs.module().Inner,

        //pub fn clone(self: *const Device, allocator: std.mem.Allocator) !Inner {
        //    return switch (@as(InnerType, self.*)) {
        //        inline else => self.*,
        //        .ccvs => Inner{
        //            .ccvs = try @field(
        //                self,
        //                @tagName(InnerType.ccvs),
        //            ).clone(allocator),
        //        },
        //    };
        //}

        //pub fn render(
        //    self: *const Inner,
        //    circuit_rect: dvui.Rect.Physical,
        //    pos: GridPosition,
        //    rot: Rotation,
        //    name: []const u8,
        //    render_type: renderer.ComponentRenderType,
        //) void {
        //    switch (@as(InnerType, self.*)) {
        //        .ground => InnerType.ground.module().render(
        //            circuit_rect,
        //            pos,
        //            rot,
        //            render_type,
        //        ),
        //        inline else => |x| InnerType.module(x).render(
        //            circuit_rect,
        //            pos,
        //            rot,
        //            name,
        //            @field(self, @tagName(x)),
        //            render_type,
        //        ),
        //    }
        //}
        //
        //pub fn renderPropertyBox(self: *Inner) void {
        //    switch (@as(InnerType, self.*)) {
        //        .ground => {},
        //        inline else => |x| x.module().renderPropertyBox(
        //            &@field(self, @tagName(x)),
        //        ),
        //    }
        //}

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

        pub fn deinit(self: *Device, allocator: std.mem.Allocator) void {
            switch (@as(DeviceType, self.*)) {
                inline else => {},
                .ccvs => @field(self, @tagName(DeviceType.ccvs)).deinit(allocator),
                .cccs => @field(self, @tagName(DeviceType.cccs)).deinit(allocator),
            }
        }
    };
};
