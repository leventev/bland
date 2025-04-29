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

    pub fn getNewComponentName(self: ComponentInnerType, allocator: std.mem.Allocator) ![:0]const u8 {
        switch (self) {
            .resistor => {
                const str = try std.fmt.allocPrintZ(allocator, "R{}", .{resistor_counter});
                resistor_counter += 1;
                return str;
            },
            .voltage_source => {
                const str = try std.fmt.allocPrintZ(allocator, "V{}", .{voltage_source_counter});
                voltage_source_counter += 1;
                return str;
            },
            .ground => {
                const str = try std.fmt.allocPrintZ(allocator, "G{}", .{ground_counter});
                ground_counter += 1;
                return str;
            },
        }
    }

    // TODO: value
    pub fn formatValue(self: ComponentInnerType, value: u32, buf: []u8) !?[:0]const u8 {
        // https://juliamono.netlify.app/glyphs/
        const big_omega = '\u{03A9}';
        switch (self) {
            .resistor => {
                return try std.fmt.bufPrintZ(buf, "{}{u}", .{ value, big_omega });
            },
            .voltage_source => {
                return try std.fmt.bufPrintZ(buf, "{}V", .{value});
            },
            .ground => {
                return null;
            },
        }
    }

    pub fn getTerminals(self: ComponentInnerType, pos: GridPosition, rotation: ComponentRotation, terminals: []GridPosition) []GridPosition {
        switch (self) {
            .ground => {
                std.debug.assert(terminals.len >= 1);
                terminals[0] = GridPosition{
                    .x = pos.x,
                    .y = pos.y,
                };
                return terminals[0..1];
            },
            .resistor, .voltage_source => {
                std.debug.assert(terminals.len >= 3);
                terminals[0] = GridPosition{ .x = pos.x, .y = pos.y };
                switch (rotation) {
                    .left, .right => {
                        terminals[1] = GridPosition{ .x = pos.x + 2, .y = pos.y };
                    },
                    .top, .bottom => {
                        terminals[1] = GridPosition{ .x = pos.x, .y = pos.y + 2 };
                    },
                }
                return terminals[0..2];
            },
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

pub fn renderComponent(
    comp: ComponentInnerType,
    pos: GridPosition,
    rot: ComponentRotation,
    name: ?[:0]const u8,
    render_type: renderer.ComponentRenderType,
) void {
    switch (comp) {
        .resistor => renderer.renderResistor(pos, rot, name, render_type),
        .voltage_source => renderer.renderVoltageSource(pos, rot, name, render_type),
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

pub var resistor_counter: usize = 1;
pub var voltage_source_counter: usize = 1;
pub var ground_counter: usize = 1;

pub const Component = struct {
    pos: GridPosition,
    rotation: ComponentRotation,
    inner: ComponentInner,
    // null terminated strings so they are easier to pass to SDL
    name: [:0]const u8,

    pub fn terminals(self: Component, buffer: []GridPosition) []GridPosition {
        return @as(ComponentInnerType, self.inner).getTerminals(
            self.pos,
            self.rotation,
            buffer[0..],
        );
    }

    pub fn render(self: Component) void {
        renderComponent(self.inner, self.pos, self.rotation, self.name, .normal);
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
