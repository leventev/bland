const std = @import("std");
const circuit = @import("circuit.zig");
const component = @import("component.zig");
const renderer = @import("renderer.zig");
const VectorRenderer = @import("VectorRenderer.zig");

const GridPosition = circuit.GridPosition;
const GridSubposition = circuit.GridSubposition;
const Rotation = circuit.Rotation;
const ElementRenderType = renderer.ElementRenderType;
const GraphicCircuit = circuit.GraphicCircuit;

const Wire = @This();

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

pub fn render(
    self: Wire,
    vector_renderer: *const VectorRenderer,
    render_type: ElementRenderType,
    junctions: ?*const std.AutoHashMapUnmanaged(GridPosition, circuit.GraphicCircuit.Junction),
) !void {
    const zoom = switch (vector_renderer.output) {
        .screen => |s| s.zoom,
        else => 1,
    };

    const instructions: []const VectorRenderer.BrushInstruction = &.{
        .{ .snap_pixel_set = true },
        .{ .move_rel = .{ .x = 1, .y = 0 } },
        .{ .stroke = .{ .base_thickness = 1 } },
    };

    var scale: f32 = @floatFromInt(self.length);
    var x: f32 = @floatFromInt(self.pos.x);
    var y: f32 = @floatFromInt(self.pos.y);
    if (junctions) |js| {
        const start_circle_rendered = if (js.get(self.pos)) |junction|
            junction.kind() != .none
        else
            false;

        const end_circle_rendered = if (js.get(self.end())) |junction|
            junction.kind() != .none
        else
            false;

        const sign: f32 = @floatFromInt(std.math.sign(self.length));

        if (start_circle_rendered) {
            scale -= sign * GraphicCircuit.junction_radius;
            switch (self.direction) {
                .horizontal => x += sign * GraphicCircuit.junction_radius,
                .vertical => y += sign * GraphicCircuit.junction_radius,
            }
        }
        if (end_circle_rendered) {
            scale -= sign * GraphicCircuit.junction_radius;
        }
    }

    const colors = render_type.colors();
    const thickness = render_type.wireThickness();
    const rotation: f32 = if (self.direction == .vertical) std.math.pi / 2.0 else 0.0;
    try vector_renderer.render(
        instructions,
        .{
            .translate = .{
                .x = x,
                .y = y,
            },
            .scale = .both(scale),
            .line_scale = thickness * zoom,
            .rotate = rotation,
        },
        .{ .stroke_color = colors.wire_color },
    );
}

pub fn getOccupiedGridPositions(
    self: Wire,
    occupied: []component.OccupiedGridPosition,
) []component.OccupiedGridPosition {
    const abs_len = @abs(self.length);
    const point_count = abs_len + 1;
    std.debug.assert(point_count < occupied.len);
    const negative = self.length < 0;

    for (0..point_count) |i| {
        const idx: i32 = if (negative) -@as(i32, @intCast(i)) else @intCast(i);
        const pos: GridPosition = if (self.direction == .horizontal) .{
            .x = self.pos.x + idx,
            .y = self.pos.y,
        } else .{
            .x = self.pos.x,
            .y = self.pos.y + idx,
        };
        occupied[i] = component.OccupiedGridPosition{
            .pos = pos,
            .terminal = true,
        };
    }

    return occupied[0..point_count];
}

const WireIterator = struct {
    wire: Wire,
    idx: u32,

    pub fn next(self: *WireIterator) ?GridPosition {
        if (self.idx > @abs(self.wire.length)) return null;
        const sign: i32 = if (self.wire.length > 0) 1 else -1;
        const increment: i32 = @as(i32, @intCast(self.idx)) * sign;
        self.idx += 1;
        switch (self.wire.direction) {
            .horizontal => return GridPosition{
                .x = self.wire.pos.x + increment,
                .y = self.wire.pos.y,
            },
            .vertical => return GridPosition{
                .x = self.wire.pos.x,
                .y = self.wire.pos.y + increment,
            },
        }
    }
};

pub fn iterator(self: Wire) WireIterator {
    return WireIterator{
        .wire = self,
        .idx = 0,
    };
}

pub fn intersectsWire(self: Wire, other: Wire) bool {
    // TODO: optimize
    var it1 = self.iterator();
    while (it1.next()) |pos1| {
        var it2 = other.iterator();
        while (it2.next()) |pos2| {
            if (pos1.eql(pos2)) return true;
        }
    }

    return false;
}

pub fn hovered(
    self: Wire,
    m_pos: GridSubposition,
    zoom_scale: f32,
) bool {
    const grid_size = VectorRenderer.grid_cell_px_size * zoom_scale;
    const tolerance_px = 7;
    const tolerance = tolerance_px / grid_size;

    var sp = GridSubposition{
        .x = @floatFromInt(self.pos.x),
        .y = @floatFromInt(self.pos.y),
    };
    var ep = GridSubposition{
        .x = @floatFromInt(self.end().x),
        .y = @floatFromInt(self.end().y),
    };

    if (self.length < 0) {
        const tmp = sp;
        sp = ep;
        ep = tmp;
    }

    switch (self.direction) {
        .horizontal => {
            const x_within = m_pos.x >= sp.x and m_pos.x <= ep.x;
            const y_within = @abs(m_pos.y - sp.y) <= tolerance;
            return x_within and y_within;
        },
        .vertical => {
            const y_within = m_pos.y >= sp.y and m_pos.y <= ep.y;
            const x_within = @abs(m_pos.x - sp.x) <= tolerance;
            return x_within and y_within;
        },
    }
    return false;
}
