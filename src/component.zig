const global = @import("global.zig");
const renderer = @import("renderer.zig");
const sdl = global.sdl;

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
        var mouse_x: i32 = undefined;
        var mouse_y: i32 = undefined;
        _ = sdl.SDL_GetMouseState(@ptrCast(&mouse_x), @ptrCast(&mouse_y));

        const world_pos = renderer.WorldPosition.fromScreenPosition(
            renderer.ScreenPosition{ .x = mouse_x, .y = mouse_y },
        );
        var grid_pos = GridPosition.fromWorldPosition(world_pos);
        grid_pos = self.centerForMouse(rotation, grid_pos);

        if (@mod(mouse_x, global.grid_size) > global.grid_size / 2)
            grid_pos.x += 1;

        if (@mod(mouse_y, global.grid_size) > global.grid_size / 2)
            grid_pos.y += 1;

        return grid_pos;
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
