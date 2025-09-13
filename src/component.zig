const std = @import("std");

const global = @import("global.zig");
const renderer = @import("renderer.zig");
const circuit = @import("circuit.zig");
const resistor = @import("components/resistor.zig");
const voltage_source = @import("components/voltage_source.zig");
const ground = @import("components/ground.zig");

const dvui = @import("dvui");

const GridPosition = circuit.GridPosition;

pub const OccupiedGridPosition = struct {
    pos: GridPosition,
    terminal: bool,
};

pub fn occupiedPointsIntersect(occupied1: []OccupiedGridPosition, occupied2: []OccupiedGridPosition) bool {
    for (occupied1) |p1| {
        for (occupied2) |p2| {
            if (p1.pos.eql(p2.pos) and (!p1.terminal or !p2.terminal)) return true;
        }
    }
    return false;
}

pub const max_component_name_length = 20;

pub const Component = struct {
    pub const Rotation = enum {
        right,
        bottom,
        left,
        top,
    };

    pos: GridPosition,

    rotation: Rotation,
    inner: Inner,
    // TODO: temporary
    terminal_node_ids: [2]usize,
    // name_buffer is max_component_name_length bytes long allocated
    name_buffer: []u8,
    // name is a window into name_buffer
    name: []u8,

    pub fn otherNode(self: Component, node_id: usize) usize {
        if (self.terminal_node_ids[0] == node_id) return self.terminal_node_ids[1];
        if (self.terminal_node_ids[1] == node_id) return self.terminal_node_ids[0];
        @panic("invalid node id");
    }

    pub fn terminals(self: Component, buffer: []GridPosition) []GridPosition {
        return @as(InnerType, self.inner).getTerminals(
            self.pos,
            self.rotation,
            buffer[0..],
        );
    }

    pub fn render(self: Component, circuit_rect: dvui.Rect.Physical, render_type: renderer.ComponentRenderType) void {
        self.inner.render(
            circuit_rect,
            self.pos,
            self.rotation,
            self.name,
            render_type,
        );
    }

    pub fn intersects(self: Component, positions: []OccupiedGridPosition) bool {
        var buffer: [100]OccupiedGridPosition = undefined;

        const self_positons = @as(InnerType, self.inner).getOccupiedGridPositions(
            self.pos,
            self.rotation,
            buffer[0..],
        );
        return occupiedPointsIntersect(self_positons, positions);
    }

    pub fn setNewComponentName(self: *Component) !void {
        self.name = try @as(InnerType, self.inner).setNewComponentName(self.name_buffer);
    }

    pub const InnerType = enum {
        resistor,
        voltage_source,
        ground,

        fn centerForMouse(self: InnerType, rotation: Rotation, pos: GridPosition) GridPosition {
            switch (self) {
                .resistor => {
                    return resistor.centerForMouse(pos, rotation);
                },
                .voltage_source => {
                    return voltage_source.centerForMouse(pos, rotation);
                },
                .ground => return pos,
            }
        }

        pub fn defaultValue(self: InnerType) Inner {
            switch (self) {
                .resistor => return resistor.defaultValue(),
                .voltage_source => return voltage_source.defaultValue(),
                .ground => return Inner{ .ground = {} },
            }
        }

        fn setNewComponentName(self: InnerType, buff: []u8) ![]u8 {
            return switch (self) {
                .resistor => resistor.setNewComponentName(buff),
                .voltage_source => voltage_source.setNewComponentName(buff),
                .ground => ground.setNewComponentName(buff),
            };
        }

        pub fn getTerminals(
            self: InnerType,
            pos: GridPosition,
            rotation: Rotation,
            terminals_buff: []GridPosition,
        ) []GridPosition {
            return switch (self) {
                .ground => ground.getTerminals(pos, rotation, terminals_buff),
                .resistor => resistor.getTerminals(pos, rotation, terminals_buff),
                .voltage_source => voltage_source.getTerminals(pos, rotation, terminals_buff),
            };
        }

        pub fn getOccupiedGridPositions(
            self: InnerType,
            pos: GridPosition,
            rotation: Rotation,
            occupied: []OccupiedGridPosition,
        ) []OccupiedGridPosition {
            return switch (self) {
                .ground => ground.getOccupiedGridPositions(pos, rotation, occupied),
                .resistor => resistor.getOccupiedGridPositions(pos, rotation, occupied),
                .voltage_source => voltage_source.getOccupiedGridPositions(pos, rotation, occupied),
            };
        }

        pub fn gridPositionFromScreenPos(
            self: InnerType,
            circuit_rect: dvui.Rect.Physical,
            pos: dvui.Point.Physical,
            rotation: Rotation,
        ) GridPosition {
            const grid_pos = circuit.gridPositionFromPos(circuit_rect, pos);
            return self.centerForMouse(rotation, grid_pos);
        }

        pub fn renderHolding(
            self: Component.InnerType,
            circuit_area: dvui.Rect.Physical,
            pos: GridPosition,
            rot: Component.Rotation,
            render_type: renderer.ComponentRenderType,
        ) void {
            switch (self) {
                .resistor => resistor.render(circuit_area, pos, rot, null, null, render_type),
                .voltage_source => voltage_source.render(circuit_area, pos, rot, null, null, render_type),
                .ground => ground.render(circuit_area, pos, rot, render_type),
            }
        }
    };

    pub const Inner = union(InnerType) {
        resistor: f32,
        voltage_source: f32,
        ground: void,

        pub fn render(
            self: Component.Inner,
            circuit_rect: dvui.Rect.Physical,
            pos: GridPosition,
            rot: Component.Rotation,
            name: []const u8,
            render_type: renderer.ComponentRenderType,
        ) void {
            switch (self) {
                .resistor => |r| resistor.render(circuit_rect, pos, rot, name, r, render_type),
                .voltage_source => |v| voltage_source.render(circuit_rect, pos, rot, name, v, render_type),
                .ground => ground.render(circuit_rect, pos, rot, render_type),
            }
        }
    };
};
