const std = @import("std");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");

const Component = component.Component;
const GridPosition = circuit.GridPosition;
const Rotation = circuit.Rotation;

pub fn twoTerminalOccupiedPoints(
    pos: GridPosition,
    rotation: Rotation,
    occupied: []component.OccupiedGridPosition,
) []component.OccupiedGridPosition {
    std.debug.assert(occupied.len >= 3);
    occupied[0] = component.OccupiedGridPosition{
        .pos = GridPosition{ .x = pos.x, .y = pos.y },
        .terminal = true,
    };
    switch (rotation) {
        .left => {
            occupied[1] = component.OccupiedGridPosition{
                .pos = GridPosition{ .x = pos.x - 1, .y = pos.y },
                .terminal = false,
            };

            occupied[2] = component.OccupiedGridPosition{
                .pos = GridPosition{ .x = pos.x - 2, .y = pos.y },
                .terminal = true,
            };
        },
        .right => {
            occupied[1] = component.OccupiedGridPosition{
                .pos = GridPosition{ .x = pos.x + 1, .y = pos.y },
                .terminal = false,
            };

            occupied[2] = component.OccupiedGridPosition{
                .pos = GridPosition{ .x = pos.x + 2, .y = pos.y },
                .terminal = true,
            };
        },
        .bottom => {
            occupied[1] = component.OccupiedGridPosition{
                .pos = GridPosition{ .x = pos.x, .y = pos.y + 1 },
                .terminal = false,
            };

            occupied[2] = component.OccupiedGridPosition{
                .pos = GridPosition{ .x = pos.x, .y = pos.y + 2 },
                .terminal = true,
            };
        },
        .top => {
            occupied[1] = component.OccupiedGridPosition{
                .pos = GridPosition{ .x = pos.x, .y = pos.y - 1 },
                .terminal = false,
            };

            occupied[2] = component.OccupiedGridPosition{
                .pos = GridPosition{ .x = pos.x, .y = pos.y - 2 },
                .terminal = true,
            };
        },
    }
    return occupied[0..3];
}

pub fn twoTerminalTerminals(
    pos: GridPosition,
    rotation: Rotation,
    terminals: []GridPosition,
) []GridPosition {
    terminals[0] = GridPosition{ .x = pos.x, .y = pos.y };
    switch (rotation) {
        .left => {
            terminals[1] = GridPosition{ .x = pos.x - 2, .y = pos.y };
        },
        .right => {
            terminals[1] = GridPosition{ .x = pos.x + 2, .y = pos.y };
        },
        .bottom => {
            terminals[1] = GridPosition{ .x = pos.x, .y = pos.y + 2 };
        },
        .top => {
            terminals[1] = GridPosition{ .x = pos.x, .y = pos.y - 2 };
        },
    }
    return terminals[0..2];
}

pub fn twoTerminalCenterForMouse(
    pos: GridPosition,
    rotation: Rotation,
) GridPosition {
    switch (rotation) {
        .top => return GridPosition{ .x = pos.x, .y = pos.y + 1 },
        .bottom => return GridPosition{ .x = pos.x, .y = pos.y - 1 },
        .left => return GridPosition{ .x = pos.x + 1, .y = pos.y },
        .right => return GridPosition{ .x = pos.x - 1, .y = pos.y },
    }
}
