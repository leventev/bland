const std = @import("std");

const global = @import("global.zig");
const renderer = @import("renderer.zig");
const circuit = @import("circuit.zig");
const sdl = global.sdl;

const GridPosition = circuit.GridPosition;

pub const ComponentInnerType = enum {
    resistor,

    fn centerForMouse(self: ComponentInnerType, rotation: ComponentRotation, pos: GridPosition) GridPosition {
        switch (self) {
            .resistor => {
                switch (rotation) {
                    .top, .bottom => {
                        return GridPosition{ .x = pos.x, .y = pos.y - 1 };
                    },
                    .left, .right => {
                        return GridPosition{ .x = pos.x - 1, .y = pos.y };
                    },
                }
            },
        }
    }

    pub fn gridPositionFromMouse(self: ComponentInnerType, rotation: ComponentRotation) GridPosition {
        const grid_pos = circuit.gridPositionFromMouse();
        return self.centerForMouse(rotation, grid_pos);
    }
};

pub const OccupiedGridPoint = struct {
    pos: GridPosition,
    terminal: bool,
};

pub fn occupiedPointsIntersect(occupied1: []OccupiedGridPoint, occupied2: []OccupiedGridPoint) bool {
    for (occupied1) |p1| {
        for (occupied2) |p2| {
            if (p1.pos.eql(p2.pos) and (!p1.terminal or !p2.terminal)) return true;
        }
    }
    return false;
}

pub fn getOccupiedGridPoints(pos: GridPosition, rotation: ComponentRotation, occupied: []OccupiedGridPoint) []OccupiedGridPoint {
    std.debug.assert(occupied.len >= 3);
    switch (rotation) {
        .left, .right => {
            occupied[0] = OccupiedGridPoint{
                .pos = GridPosition{ .x = pos.x, .y = pos.y },
                .terminal = true,
            };
            occupied[1] = OccupiedGridPoint{
                .pos = GridPosition{ .x = pos.x + 1, .y = pos.y },
                .terminal = false,
            };

            occupied[0] = OccupiedGridPoint{
                .pos = GridPosition{ .x = pos.x + 2, .y = pos.y },
                .terminal = true,
            };
        },
        .top, .bottom => {
            occupied[0] = OccupiedGridPoint{
                .pos = GridPosition{ .x = pos.x, .y = pos.y },
                .terminal = true,
            };
            occupied[1] = OccupiedGridPoint{
                .pos = GridPosition{ .x = pos.x, .y = pos.y + 1 },
                .terminal = false,
            };

            occupied[0] = OccupiedGridPoint{
                .pos = GridPosition{ .x = pos.x, .y = pos.y + 2 },
                .terminal = true,
            };
        },
    }

    return occupied[0..2];
}

pub const ComponentInner = union(ComponentInnerType) {
    resistor: u32,
};

pub const ComponentRotation = enum {
    right,
    bottom,
    left,
    top,
};

pub const Component = struct {
    pos: GridPosition,
    rotation: ComponentRotation,
    inner: ComponentInner,

    pub fn render(self: Component) void {
        switch (self.inner) {
            .resistor => renderer.renderResistor(self.pos, self.rotation, .normal),
        }
    }

    pub fn intersects(self: Component, positions: []OccupiedGridPoint) bool {
        var buffer: [100]OccupiedGridPoint = undefined;
        const self_positons = getOccupiedGridPoints(self.pos, self.rotation, buffer[0..]);
        return occupiedPointsIntersect(self_positons, positions);
    }
};
