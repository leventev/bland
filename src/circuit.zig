const std = @import("std");

const component = @import("component.zig");
const renderer = @import("renderer.zig");
const global = @import("global.zig");
const sdl = global.sdl;

pub var held_component: ?component.ComponentInnerType = .resistor;
pub var held_component_rotation: component.ComponentRotation = .right;

pub var components: std.ArrayList(component.Component) = undefined;

pub fn canPlace(pos: component.GridPosition, rotation: component.ComponentRotation) bool {
    const positions = component.getOccupiedGridPoints(pos, rotation);
    for (components.items) |comp| {
        if (comp.intersects(positions)) return false;
    }

    return true;
}
