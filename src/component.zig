const std = @import("std");
const dvui = @import("dvui");
const bland = @import("bland");
const circuit = @import("circuit.zig");
const global = @import("global.zig");
const renderer = @import("renderer.zig");

const Float = bland.Float;
const GridPosition = circuit.GridPosition;
const Rotation = circuit.Rotation;
const Component = bland.Component;
const Device = Component.Device;
const DeviceType = Component.DeviceType;

const resistor_graphics_module = @import("components/resistor.zig");
const voltage_source_graphics_module = @import("components/voltage_source.zig");
const current_source_graphics_module = @import("components/current_source.zig");
const capacitor_graphics_module = @import("components/capacitor.zig");
const inductor_graphics_module = @import("components/inductor.zig");
const ground_graphics_module = @import("components/ground.zig");
const ccvs_graphics_module = @import("components/ccvs.zig");
const cccs_graphics_module = @import("components/cccs.zig");

fn graphics_module(comptime self: DeviceType) type {
    return switch (self) {
        .resistor => resistor_graphics_module,
        .voltage_source => voltage_source_graphics_module,
        .current_source => current_source_graphics_module,
        .capacitor => capacitor_graphics_module,
        .inductor => inductor_graphics_module,
        .ground => ground_graphics_module,
        .ccvs => ccvs_graphics_module,
        .cccs => cccs_graphics_module,
    };
}

pub const OccupiedGridPosition = struct {
    pos: GridPosition,
    terminal: bool,
};

pub fn occupiedPointsIntersect(
    occupied1: []OccupiedGridPosition,
    occupied2: []OccupiedGridPosition,
) bool {
    for (occupied1) |p1| {
        for (occupied2) |p2| {
            if (p1.pos.eql(p2.pos) and (!p1.terminal or !p2.terminal)) return true;
        }
    }
    return false;
}

pub fn renderComponentHolding(
    dev_type: DeviceType,
    circuit_rect: dvui.Rect.Physical,
    pos: GridPosition,
    rot: Rotation,
    render_type: renderer.ComponentRenderType,
) void {
    switch (dev_type) {
        .ground => graphics_module(DeviceType.ground).render(
            circuit_rect,
            pos,
            rot,
            render_type,
        ),
        inline else => |x| graphics_module(x).render(
            circuit_rect,
            pos,
            rot,
            null,
            null,
            render_type,
        ),
    }
}

pub fn deviceOccupiedGridPositions(
    self: DeviceType,
    pos: GridPosition,
    rotation: Rotation,
    occupied: []OccupiedGridPosition,
) []OccupiedGridPosition {
    switch (self) {
        inline else => |x| return graphics_module(x).getOccupiedGridPositions(
            pos,
            rotation,
            occupied,
        ),
    }
}

fn deviceCenterForMouse(self: DeviceType, pos: GridPosition, rotation: Rotation) GridPosition {
    switch (self) {
        inline else => |x| return graphics_module(x).centerForMouse(
            pos,
            rotation,
        ),
    }
}

pub fn deviceGetTerminals(
    dev_type: DeviceType,
    pos: GridPosition,
    rotation: Rotation,
    terminals_buff: []GridPosition,
) []GridPosition {
    switch (dev_type) {
        inline else => |x| return graphics_module(x).getTerminals(
            pos,
            rotation,
            terminals_buff,
        ),
    }
}

pub fn gridPositionFromScreenPos(
    dev_type: DeviceType,
    circuit_rect: dvui.Rect.Physical,
    pos: dvui.Point.Physical,
    rotation: Rotation,
) GridPosition {
    const grid_pos = circuit.gridPositionFromPos(circuit_rect, pos);
    return deviceCenterForMouse(dev_type, grid_pos, rotation);
}

// TODO:
const MaxFloatValueLength = 64;

pub const GraphicComponent = struct {
    pos: GridPosition,
    rotation: Rotation,

    comp: Component,

    // name_buffer is max_component_name_length bytes long allocated
    // comp.name is a slice into name_buffer
    name_buffer: []u8,

    value_buffer: ValueBuffer,

    pub const ValueBuffer = union(Component.DeviceType) {
        ground,
        resistor: struct {
            buff: []u8,
            actual: []u8,
        },
        voltage_source: struct {
            buff: []u8,
            actual: []u8,
        },
        current_source: struct {
            buff: []u8,
            actual: []u8,
        },
        capacitor: struct {
            buff: []u8,
            actual: []u8,
        },
        inductor: struct {
            buff: []u8,
            actual: []u8,
        },
        ccvs: void,
        cccs: void,

        pub fn init(gpa: std.mem.Allocator, device_type: Component.DeviceType) !@This() {
            return switch (device_type) {
                .ground => .{ .ground = {} },
                .resistor => .{ .resistor = .{ .buff = try gpa.alloc(u8, MaxFloatValueLength), .actual = &.{} } },
                .capacitor => .{ .capacitor = .{ .buff = try gpa.alloc(u8, MaxFloatValueLength), .actual = &.{} } },
                .inductor => .{ .inductor = .{ .buff = try gpa.alloc(u8, MaxFloatValueLength), .actual = &.{} } },
                .ccvs => .{ .ccvs = {} },
                .cccs => .{ .cccs = {} },
                .voltage_source => .{ .voltage_source = .{ .buff = try gpa.alloc(u8, MaxFloatValueLength), .actual = &.{} } },
                .current_source => .{ .current_source = .{ .buff = try gpa.alloc(u8, MaxFloatValueLength), .actual = &.{} } },
            };
        }

        // TODO:
        pub fn setValue(self: *@This(), precision: usize, dev: Device) !void {
            switch (self.*) {
                .ground => {},
                .resistor => |*buf| buf.actual = try bland.units.formatPrefixBuf(buf.buff, dev.resistor, precision),
                .capacitor => |*buf| buf.actual = try bland.units.formatPrefixBuf(buf.buff, dev.capacitor, precision),
                .inductor => |*buf| buf.actual = try bland.units.formatPrefixBuf(buf.buff, dev.inductor, precision),
                .ccvs => |_| @panic("TODO"),
                .cccs => |_| @panic("TODO"),
                .voltage_source => |*buf| buf.actual = try bland.units.formatPrefixBuf(buf.buff, dev.voltage_source, precision),
                .current_source => |*buf| buf.actual = try bland.units.formatPrefixBuf(buf.buff, dev.current_source, precision),
            }
        }

        pub fn deinit(self: @This(), gpa: std.mem.Allocator) void {
            _ = self;
            _ = gpa;
            @panic("TODO");
        }
    };

    pub fn init(
        gpa: std.mem.Allocator,
        grid_pos: circuit.GridPosition,
        rotation: circuit.Rotation,
        device_type: DeviceType,
    ) !GraphicComponent {
        var graphic_comp = GraphicComponent{
            .pos = grid_pos,
            .rotation = rotation,
            .name_buffer = try gpa.alloc(u8, bland.component.max_component_name_length),
            .comp = bland.Component{
                .name = &.{},
                .device = try device_type.defaultValue(gpa),
                .terminal_node_ids = try gpa.alloc(usize, 2),
            },
            .value_buffer = try .init(gpa, circuit.held_component),
        };
        try graphic_comp.setNewComponentName();
        try graphic_comp.value_buffer.setValue(0, graphic_comp.comp.device);

        return graphic_comp;
    }

    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        allocator.free(self.name_buffer);
        self.name = &.{};
        allocator.free(self.terminal_node_ids);
        self.value_buffer.deinit();
        self.inner.deinit(allocator);
    }

    pub fn terminals(self: *const GraphicComponent, buffer: []GridPosition) []GridPosition {
        return deviceGetTerminals(
            @as(Component.DeviceType, self.comp.device),
            self.pos,
            self.rotation,
            buffer[0..],
        );
    }

    pub fn render(
        self: *const GraphicComponent,
        circuit_rect: dvui.Rect.Physical,
        render_type: renderer.ComponentRenderType,
    ) void {
        switch (@as(DeviceType, self.comp.device)) {
            .ground => graphics_module(DeviceType.ground).render(
                circuit_rect,
                self.pos,
                self.rotation,
                render_type,
            ),
            inline else => |x| graphics_module(x).render(
                circuit_rect,
                self.pos,
                self.rotation,
                self.comp.name,
                self.value_buffer,
                render_type,
            ),
        }
    }

    pub fn intersects(self: *const GraphicComponent, positions: []OccupiedGridPosition) bool {
        var buffer: [100]OccupiedGridPosition = undefined;

        const self_positons = self.getOccupiedGridPositions(buffer[0..]);
        return occupiedPointsIntersect(self_positons, positions);
    }

    pub fn getOccupiedGridPositions(
        self: *const GraphicComponent,
        position_buffer: []OccupiedGridPosition,
    ) []OccupiedGridPosition {
        return deviceOccupiedGridPositions(
            @as(Component.DeviceType, self.comp.device),
            self.pos,
            self.rotation,
            position_buffer[0..],
        );
    }

    pub fn renderPropertyBox(self: *GraphicComponent, selected_component_changed: bool) void {
        switch (@as(DeviceType, self.comp.device)) {
            .ground => {},
            inline else => |x| graphics_module(x).renderPropertyBox(
                &@field(self.comp.device, @tagName(x)),
                &self.value_buffer,
                selected_component_changed,
            ),
        }
    }

    pub fn setNewComponentName(self: *GraphicComponent) !void {
        self.comp.name = switch (@as(DeviceType, self.comp.device)) {
            inline else => |x| try graphics_module(x).setNewComponentName(
                self.name_buffer,
            ),
        };
    }
};
