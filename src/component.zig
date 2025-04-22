const std = @import("std");

const global = @import("global.zig");
const renderer = @import("renderer.zig");
const circuit = @import("circuit.zig");
const sdl = global.sdl;

const GridPosition = circuit.GridPosition;

pub const ComponentInnerType = enum {
    resistor,
    voltage_source,
    ground,

    fn centerForMouse(self: ComponentInnerType, rotation: ComponentRotation, pos: GridPosition) GridPosition {
        switch (self) {
            .resistor, .voltage_source => {
                switch (rotation) {
                    .top, .bottom => {
                        return GridPosition{ .x = pos.x, .y = pos.y - 1 };
                    },
                    .left, .right => {
                        return GridPosition{ .x = pos.x - 1, .y = pos.y };
                    },
                }
            },
            .ground => return pos,
        }
    }

    pub fn defaultValue(self: ComponentInnerType) ComponentInner {
        switch (self) {
            .resistor => return ComponentInner{ .resistor = 1 },
            .voltage_source => return ComponentInner{ .voltage_source = 1 },
            .ground => return ComponentInner{ .ground = {} },
        }
    }

    pub fn getOccupiedGridPoints(self: ComponentInnerType, pos: GridPosition, rotation: ComponentRotation, occupied: []OccupiedGridPoint) []OccupiedGridPoint {
        switch (self) {
            .ground => {
                std.debug.assert(occupied.len >= 2);
                occupied[0] = OccupiedGridPoint{
                    .pos = GridPosition{ .x = pos.x, .y = pos.y },
                    .terminal = true,
                };
                switch (rotation) {
                    .left => {
                        occupied[1] = OccupiedGridPoint{
                            .pos = GridPosition{ .x = pos.x - 1, .y = pos.y },
                            .terminal = false,
                        };
                    },
                    .right => {
                        occupied[1] = OccupiedGridPoint{
                            .pos = GridPosition{ .x = pos.x + 1, .y = pos.y },
                            .terminal = false,
                        };
                    },
                    .top => {
                        occupied[1] = OccupiedGridPoint{
                            .pos = GridPosition{ .x = pos.x, .y = pos.y - 1 },
                            .terminal = false,
                        };
                    },
                    .bottom => {
                        occupied[1] = OccupiedGridPoint{
                            .pos = GridPosition{ .x = pos.x, .y = pos.y + 1 },
                            .terminal = false,
                        };
                    },
                }
                return occupied[0..2];
            },
            .resistor, .voltage_source => {
                std.debug.assert(occupied.len >= 3);
                occupied[0] = OccupiedGridPoint{
                    .pos = GridPosition{ .x = pos.x, .y = pos.y },
                    .terminal = true,
                };
                switch (rotation) {
                    .left, .right => {
                        occupied[1] = OccupiedGridPoint{
                            .pos = GridPosition{ .x = pos.x + 1, .y = pos.y },
                            .terminal = false,
                        };

                        occupied[2] = OccupiedGridPoint{
                            .pos = GridPosition{ .x = pos.x + 2, .y = pos.y },
                            .terminal = true,
                        };
                    },
                    .top, .bottom => {
                        occupied[1] = OccupiedGridPoint{
                            .pos = GridPosition{ .x = pos.x, .y = pos.y + 1 },
                            .terminal = false,
                        };

                        occupied[2] = OccupiedGridPoint{
                            .pos = GridPosition{ .x = pos.x, .y = pos.y + 2 },
                            .terminal = true,
                        };
                    },
                }
                return occupied[0..3];
            },
        }
    }

    pub fn gridPositionFromMouse(self: ComponentInnerType, rotation: ComponentRotation) GridPosition {
        const grid_pos = circuit.gridPositionFromMouse();
        return self.centerForMouse(rotation, grid_pos);
    }
};

pub fn renderComponent(comp: ComponentInnerType, pos: GridPosition, rot: ComponentRotation, render_type: renderer.ComponentRenderType) void {
    switch (comp) {
        .resistor => renderer.renderResistor(pos, rot, render_type),
        .voltage_source => renderer.renderVoltageSource(pos, rot, render_type),
        .ground => renderer.renderGround(pos, rot, render_type),
    }
}

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

pub const ComponentInner = union(ComponentInnerType) {
    resistor: f32,
    voltage_source: f32,
    ground: void,
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
        renderComponent(self.inner, self.pos, self.rotation, .normal);
    }

    pub fn intersects(self: Component, positions: []OccupiedGridPoint) bool {
        var buffer: [100]OccupiedGridPoint = undefined;

        const self_positons = @as(ComponentInnerType, self.inner).getOccupiedGridPoints(
            self.pos,
            self.rotation,
            buffer[0..],
        );
        return occupiedPointsIntersect(self_positons, positions);
    }
};
