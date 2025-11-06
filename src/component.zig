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

pub fn renderComponent(
    device: *const Device,
    circuit_rect: dvui.Rect.Physical,
    pos: GridPosition,
    rot: Rotation,
    name: []const u8,
    render_type: renderer.ComponentRenderType,
) void {
    switch (@as(DeviceType, device.*)) {
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
            name,
            @field(device, @tagName(x)),
            render_type,
        ),
    }
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

pub const GraphicComponent = struct {
    pos: GridPosition,
    rotation: Rotation,

    comp: Component,

    // name_buffer is max_component_name_length bytes long allocated
    // comp.name is a slice into name_buffer
    name_buffer: []u8,

    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        allocator.free(self.name_buffer);
        self.name = &.{};
        allocator.free(self.terminal_node_ids);
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
        renderComponent(
            &self.comp.device,
            circuit_rect,
            self.pos,
            self.rotation,
            self.comp.name,
            render_type,
        );
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

    pub fn renderPropertyBox(self: *GraphicComponent) void {
        switch (@as(DeviceType, self.comp.device)) {
            .ground => {},
            inline else => |x| graphics_module(x).renderPropertyBox(
                &@field(self.comp.device, @tagName(x)),
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
