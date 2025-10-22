const std = @import("std");

const global = @import("global.zig");
const renderer = @import("renderer.zig");
const circuit = @import("circuit.zig");

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

const Rotation = circuit.Rotation;

pub const Component = struct {
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

    pub fn renderPropertyBox(self: *Component) void {
        self.inner.renderPropertyBox();
    }

    pub fn stampMatrix(self: *const Component, mna: *circuit.MNA, current_group_2_idx: ?usize) void {
        self.inner.stampMatrix(&self.terminal_node_ids, mna, current_group_2_idx);
    }

    pub const InnerType = enum {
        ground,
        resistor,
        voltage_source,
        current_source,
        capacitor,
        ccvs,

        fn module(comptime self: InnerType) type {
            return switch (self) {
                .resistor => @import("components/resistor.zig"),
                .voltage_source => @import("components/voltage_source.zig"),
                .current_source => @import("components/current_source.zig"),
                .capacitor => @import("components/capacitor.zig"),
                .ground => @import("components/ground.zig"),
                .ccvs => @import("components/ccvs.zig"),
            };
        }

        fn centerForMouse(self: InnerType, pos: GridPosition, rotation: Rotation) GridPosition {
            switch (self) {
                inline else => |x| return x.module().centerForMouse(
                    pos,
                    rotation,
                ),
            }
        }

        pub fn defaultValue(self: InnerType, allocator: std.mem.Allocator) !Inner {
            switch (self) {
                inline else => |x| return x.module().defaultValue(allocator),
            }
        }

        fn setNewComponentName(self: InnerType, buff: []u8) ![]u8 {
            switch (self) {
                inline else => |x| return x.module().setNewComponentName(buff),
            }
        }

        pub fn getTerminals(
            self: InnerType,
            pos: GridPosition,
            rotation: Rotation,
            terminals_buff: []GridPosition,
        ) []GridPosition {
            switch (self) {
                inline else => |x| return x.module().getTerminals(
                    pos,
                    rotation,
                    terminals_buff,
                ),
            }
        }

        pub fn getOccupiedGridPositions(
            self: InnerType,
            pos: GridPosition,
            rotation: Rotation,
            occupied: []OccupiedGridPosition,
        ) []OccupiedGridPosition {
            switch (self) {
                inline else => |x| return x.module().getOccupiedGridPositions(
                    pos,
                    rotation,
                    occupied,
                ),
            }
        }

        pub fn gridPositionFromScreenPos(
            self: InnerType,
            circuit_rect: dvui.Rect.Physical,
            pos: dvui.Point.Physical,
            rotation: Rotation,
        ) GridPosition {
            const grid_pos = circuit.gridPositionFromPos(circuit_rect, pos);
            return self.centerForMouse(grid_pos, rotation);
        }

        pub fn renderHolding(
            self: Component.InnerType,
            circuit_rect: dvui.Rect.Physical,
            pos: GridPosition,
            rot: Rotation,
            render_type: renderer.ComponentRenderType,
        ) void {
            switch (self) {
                .ground => InnerType.ground.module().render(
                    circuit_rect,
                    pos,
                    rot,
                    render_type,
                ),
                inline else => |x| x.module().render(
                    circuit_rect,
                    pos,
                    rot,
                    null,
                    null,
                    render_type,
                ),
            }
        }
    };

    pub const Inner = union(InnerType) {
        ground,
        resistor: circuit.FloatType,
        voltage_source: circuit.FloatType,
        current_source: circuit.FloatType,
        capacitor: circuit.FloatType,
        ccvs: InnerType.ccvs.module().Inner,

        pub fn render(
            self: *const Inner,
            circuit_rect: dvui.Rect.Physical,
            pos: GridPosition,
            rot: Rotation,
            name: []const u8,
            render_type: renderer.ComponentRenderType,
        ) void {
            switch (@as(InnerType, self.*)) {
                .ground => InnerType.ground.module().render(
                    circuit_rect,
                    pos,
                    rot,
                    render_type,
                ),
                inline else => |x| InnerType.module(x).render(
                    circuit_rect,
                    pos,
                    rot,
                    name,
                    @field(self, @tagName(x)),
                    render_type,
                ),
            }
        }

        pub fn renderPropertyBox(self: *Inner) void {
            switch (@as(InnerType, self.*)) {
                .ground => {},
                inline else => |x| x.module().renderPropertyBox(
                    &@field(self, @tagName(x)),
                ),
            }
        }

        pub fn stampMatrix(
            self: *const Inner,
            terminal_node_ids: []const usize,
            mna: *circuit.MNA,
            current_group_2_idx: ?usize,
        ) void {
            switch (@as(InnerType, self.*)) {
                .ground => {},
                inline else => |x| x.module().stampMatrix(
                    @field(self, @tagName(x)),
                    terminal_node_ids,
                    mna,
                    current_group_2_idx,
                ),
            }
        }

        pub fn deinit(self: *Inner, allocator: std.mem.Allocator) void {
            switch (@as(InnerType, self.*)) {
                inline else => {},
                .ccvs => @field(self, @tagName(InnerType.ccvs)).deinit(allocator),
            }
        }
    };
};
