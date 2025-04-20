const std = @import("std");

const component = @import("component.zig");
const renderer = @import("renderer.zig");
const global = @import("global.zig");
const sdl = global.sdl;

pub const PlacementMode = enum {
    none,
    component,
    wire,
};

pub const GridPosition = struct {
    x: i32,
    y: i32,

    pub fn fromWorldPosition(pos: renderer.WorldPosition) GridPosition {
        return GridPosition{
            .x = @divTrunc(pos.x, global.grid_size),
            .y = @divTrunc(pos.y, global.grid_size),
        };
    }

    pub fn eql(self: GridPosition, other: GridPosition) bool {
        return self.x == other.x and self.y == other.y;
    }
};

pub const Wire = struct {
    pos: GridPosition,
    // length can be negative
    length: i32,
    direction: Direction,

    pub const Direction = enum {
        horizontal,
        vertical,
    };

    pub fn end(self: Wire) GridPosition {
        switch (self.direction) {
            .horizontal => return GridPosition{
                .x = self.pos.x + self.length,
                .y = self.pos.y,
            },
            .vertical => return GridPosition{
                .x = self.pos.x,
                .y = self.pos.y + self.length,
            },
        }
    }
};

pub var placement_mode: PlacementMode = .none;

pub var held_component: component.ComponentInnerType = .resistor;
pub var held_component_rotation: component.ComponentRotation = .right;

pub var held_wire_p1: ?GridPosition = null;

pub var components: std.ArrayList(component.Component) = undefined;
pub var wires: std.ArrayList(Wire) = undefined;

pub fn canPlaceComponent(pos: GridPosition, rotation: component.ComponentRotation) bool {
    var buffer: [100]component.OccupiedGridPoint = undefined;
    const positions = component.getOccupiedGridPoints(pos, rotation, buffer[0..]);
    for (components.items) |comp| {
        if (comp.intersects(positions)) return false;
    }

    var buffer2: [100]component.OccupiedGridPoint = undefined;
    for (wires.items) |wire| {
        const wire_positions = getOccupiedGridPoints(wire, buffer2[0..]);
        if (component.occupiedPointsIntersect(positions, wire_positions)) return false;
    }

    return true;
}

fn getOccupiedGridPoints(wire: Wire, occupied: []component.OccupiedGridPoint) []component.OccupiedGridPoint {
    const abs_len = @abs(wire.length);
    std.debug.assert(abs_len < occupied.len);
    const negative = wire.length < 0;

    for (0..@intCast(abs_len)) |i| {
        const idx: i32 = if (negative) -@as(i32, @intCast(i)) else @intCast(i);
        const pos: GridPosition = if (wire.direction == .horizontal) .{
            .x = wire.pos.x + idx,
            .y = wire.pos.y,
        } else .{
            .x = wire.pos.x,
            .y = wire.pos.y + idx,
        };
        occupied[i] = component.OccupiedGridPoint{
            .pos = pos,
            .terminal = true,
        };
    }

    return occupied[0..abs_len];
}

pub fn canPlaceWire(wire: Wire) bool {
    var buffer: [100]component.OccupiedGridPoint = undefined;
    const positions = getOccupiedGridPoints(wire, buffer[0..]);

    for (components.items) |comp| {
        if (comp.intersects(positions)) return false;
    }

    for (wires.items) |other_wire| {
        if (wire.direction != other_wire.direction) continue;
        if (wire.direction == .horizontal) {
            if (wire.pos.y != other_wire.pos.y) continue;

            const x1 = wire.pos.x + wire.length;
            const x2 = other_wire.pos.x + other_wire.length;

            const x1_start = @min(wire.pos.x, x1);
            const x1_end = @max(wire.pos.x, x1);
            const x2_start = @min(other_wire.pos.x, x2);
            const x2_end = @max(other_wire.pos.x, x2);

            const intersect_side1 = x2_end > x1_start and x2_end < x1_end;
            const intersect_side2 = x2_start > x1_start and x2_start < x1_end;
            const interesct_inside = x1_start >= x2_start and x1_end <= x2_end;
            if (intersect_side1 or intersect_side2 or interesct_inside) return false;
        } else {
            if (wire.pos.x != other_wire.pos.x) continue;

            const y1 = wire.pos.y + wire.length;
            const y2 = other_wire.pos.y + other_wire.length;

            const y1_start = @min(wire.pos.y, y1);
            const y1_end = @max(wire.pos.y, y1);
            const y2_start = @min(other_wire.pos.y, y2);
            const y2_end = @max(other_wire.pos.y, y2);

            const intersect_side1 = y2_end > y1_start and y2_end < y1_end;
            const intersect_side2 = y2_start > y1_start and y2_start < y1_end;
            const interesct_inside = y1_start >= y2_start and y1_end <= y2_end;
            if (intersect_side1 or intersect_side2 or interesct_inside) return false;
        }
    }

    return true;
}

pub fn gridPositionFromMouse() GridPosition {
    var mouse_x: i32 = undefined;
    var mouse_y: i32 = undefined;
    _ = sdl.SDL_GetMouseState(@ptrCast(&mouse_x), @ptrCast(&mouse_y));

    const world_pos = renderer.WorldPosition.fromScreenPosition(
        renderer.ScreenPosition{ .x = mouse_x, .y = mouse_y },
    );

    var grid_pos = GridPosition.fromWorldPosition(world_pos);

    if (@mod(mouse_x, global.grid_size) > global.grid_size / 2)
        grid_pos.x += 1;

    if (@mod(mouse_y, global.grid_size) > global.grid_size / 2)
        grid_pos.y += 1;

    return grid_pos;
}
