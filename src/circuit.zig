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
};

pub var placement_mode: PlacementMode = .none;

pub var held_component: component.ComponentInnerType = .resistor;
pub var held_component_rotation: component.ComponentRotation = .right;

pub var held_wire_p1: ?GridPosition = null;

pub var components: std.ArrayList(component.Component) = undefined;
pub var wires: std.ArrayList(Wire) = undefined;

pub fn canPlace(pos: GridPosition, rotation: component.ComponentRotation) bool {
    const positions = component.getOccupiedGridPoints(pos, rotation);
    for (components.items) |comp| {
        if (comp.intersects(positions)) return false;
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
