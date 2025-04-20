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

pub fn getOccupiedGridPoints(pos: GridPosition, rotation: ComponentRotation) [3]GridPosition {
    switch (rotation) {
        .left, .right => return [3]GridPosition{
            GridPosition{
                .x = pos.x,
                .y = pos.y,
            },
            GridPosition{
                .x = pos.x + 1,
                .y = pos.y,
            },
            GridPosition{
                .x = pos.x + 2,
                .y = pos.y,
            },
        },
        .top, .bottom => return [3]GridPosition{
            GridPosition{
                .x = pos.x,
                .y = pos.y,
            },
            GridPosition{
                .x = pos.x,
                .y = pos.y + 1,
            },
            GridPosition{
                .x = pos.x,
                .y = pos.y + 2,
            },
        },
    }
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

    // TODO: handle 2 port networks
    pub fn intersects(self: Component, positions: [3]GridPosition) bool {
        const self_positons = getOccupiedGridPoints(self.pos, self.rotation);

        // 2-terminal components only interesct when the middle grid point is shared with another component
        if (self_positons[1].eql(positions[0]) or self_positons[1].eql(positions[1]) or self_positons[1].eql(positions[2]))
            return true;
        if (positions[1].eql(self_positons[0]) or positions[1].eql(self_positons[2]))
            return true;

        return false;
    }
};
