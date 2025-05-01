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
};

pub var placement_mode: PlacementMode = .none;

pub var held_component: component.ComponentInnerType = .resistor;
pub var held_component_rotation: component.ComponentRotation = .right;

pub var held_wire_p1: ?GridPosition = null;

pub var components: std.ArrayList(component.Component) = undefined;
pub var wires: std.ArrayList(Wire) = undefined;

pub fn canPlaceComponent(comp_type: component.ComponentInnerType, pos: GridPosition, rotation: component.ComponentRotation) bool {
    var buffer: [100]component.OccupiedGridPoint = undefined;
    const positions = comp_type.getOccupiedGridPoints(pos, rotation, buffer[0..]);
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

// TODO: use u32 instead of usize for IDs?
const NetList = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayListUnmanaged(Node),

    const Terminal = struct {
        component_id: usize,
        terminal_id: usize,
    };

    const Node = struct {
        id: usize,
        connected_terminals: std.ArrayListUnmanaged(Terminal),
    };

    fn deinit(self: *NetList) void {
        for (self.nodes.items) |*node| {
            node.connected_terminals.deinit(self.allocator);
        }
        self.nodes.deinit(self.allocator);
        self.* = undefined;
    }
};

const TerminalWithPos = struct {
    term: NetList.Terminal,
    pos: GridPosition,
};

fn buildNetList(allocator: std.mem.Allocator) !NetList {
    const terminal_count_approx = components.items.len * 2;

    var remaining_terminals = try std.ArrayListUnmanaged(TerminalWithPos).initCapacity(
        allocator,
        terminal_count_approx,
    );
    defer remaining_terminals.deinit(allocator);

    // get all terminals
    for (components.items, 0..) |comp, comp_id| {
        // TODO: get terminal count for specific component
        var buffer: [16]GridPosition = undefined;
        const terminals = comp.terminals(buffer[0..]);
        for (terminals, 0..) |pos, term_id| {
            try remaining_terminals.append(allocator, TerminalWithPos{
                .term = NetList.Terminal{
                    .component_id = comp_id,
                    .terminal_id = term_id,
                },
                .pos = pos,
            });
        }
    }

    var nodes = std.ArrayListUnmanaged(NetList.Node){};
    errdefer nodes.deinit(allocator);

    try traverseWiresForNodes(allocator, &remaining_terminals, &nodes);

    // find all direct connections
    while (remaining_terminals.pop()) |selected_terminal| {
        var connected_terminals = std.ArrayListUnmanaged(NetList.Terminal){};
        try connected_terminals.append(allocator, selected_terminal.term);

        while (getLastConnected(selected_terminal.pos, &remaining_terminals)) |other_term| {
            try connected_terminals.append(allocator, other_term.term);
        }
        try nodes.append(allocator, NetList.Node{
            .id = nodes.items.len,
            .connected_terminals = connected_terminals,
        });
    }

    return NetList{
        .allocator = allocator,
        .nodes = nodes,
    };
}

fn getNextConnectedTerminalToWire(
    wire: Wire,
    remaining_terminals: *std.ArrayListUnmanaged(TerminalWithPos),
) ?NetList.Terminal {
    var i = remaining_terminals.items.len;
    while (i > 0) {
        i -= 1;
        const term = remaining_terminals.items[i];

        var it = wire.iterator();
        var connected = false;
        while (it.next()) |pos| {
            if (term.pos.eql(pos)) {
                connected = true;
                break;
            }
        }

        if (connected) {
            return remaining_terminals.swapRemove(i).term;
        }
    }

    return null;
}

// TODO: optimize this although i doubt this has a non negligible performance impact
fn traverseWiresForNodes(
    allocator: std.mem.Allocator,
    remaining_terminals: *std.ArrayListUnmanaged(TerminalWithPos),
    nodes: *std.ArrayListUnmanaged(NetList.Node),
) !void {
    var connected_wire_buffer = try allocator.alloc(usize, wires.items.len);
    defer allocator.free(connected_wire_buffer);

    var remaining_wires = try allocator.dupe(Wire, wires.items);
    var rem: usize = remaining_wires.len;

    while (rem > 0) {
        var connected_terminals = std.ArrayListUnmanaged(NetList.Terminal){};
        const connected_wires = getConnectedWires(
            remaining_wires,
            remaining_wires.len - 1,
            connected_wire_buffer[0..],
        );

        for (connected_wires) |wire_idx| {
            const wire = remaining_wires[wire_idx];
            while (getNextConnectedTerminalToWire(wire, remaining_terminals)) |term| {
                try connected_terminals.append(allocator, term);
            }
        }

        rem = remaining_wires.len - connected_wires.len;
        if (rem == 0) {
            allocator.free(remaining_wires);
        } else {
            var new_remaining_wires = try allocator.alloc(Wire, rem);
            var idx: usize = 0;
            for (0..remaining_wires.len) |i| {
                var should_remove = false;
                for (connected_wires) |j| {
                    if (i == j) {
                        should_remove = true;
                        break;
                    }
                }
                if (should_remove) continue;
                new_remaining_wires[idx] = remaining_wires[i];
                idx += 1;
            }
            allocator.free(remaining_wires);
            remaining_wires = new_remaining_wires;
        }

        try nodes.append(allocator, NetList.Node{
            .id = nodes.items.len,
            .connected_terminals = connected_terminals,
        });
    }
}

fn getConnectedWires(ws: []const Wire, wire_id: usize, connected_wires: []usize) []usize {
    std.debug.assert(connected_wires.len > 0);
    connected_wires[0] = wire_id;
    var i: usize = 0;
    var wire_count: usize = 1;
    while (i < wire_count) : (i += 1) {
        const directly_connected = getDirectlyConnectedWires(
            ws,
            connected_wires[i],
            connected_wires[0..wire_count],
            connected_wires[wire_count..],
        );
        wire_count += directly_connected.len;
    }

    return connected_wires[0..wire_count];
}

fn getDirectlyConnectedWires(ws: []const Wire, wire_id: usize, already_found_wires: []usize, connected_wires: []usize) []usize {
    var count: usize = 0;
    for (0..ws.len) |i| {
        if (wire_id == i) continue;

        var already_found = false;
        for (already_found_wires) |j| {
            if (i == j) {
                already_found = true;
                break;
            }
        }
        if (already_found) continue;

        if (ws[wire_id].intersectsWire(ws[i])) {
            std.debug.assert(connected_wires.len > count);
            connected_wires[count] = i;
            count += 1;
        }
    }
    return connected_wires[0..count];
}

fn getNextConnectedWire(wire: Wire, ws: *std.ArrayList(Wire)) ?Wire {
    for (0..ws.items.len) |i| {
        const w = ws.items[i];
        if (wire.intersectsWire(w)) {
            return ws.swapRemove(i);
        }
    }

    return null;
}

fn getLastConnected(pos: GridPosition, terms: *std.ArrayListUnmanaged(TerminalWithPos)) ?TerminalWithPos {
    for (0..terms.items.len) |i| {
        if (pos.eql(terms.items[i].pos)) {
            // swapRemove should be safe to use here
            return terms.swapRemove(i);
        }
    }

    return null;
}

pub fn analyse(allocator: std.mem.Allocator) void {
    var netlist = buildNetList(allocator) catch {
        std.log.err("Failed to build netlist", .{});
        return;
    };
    defer netlist.deinit();

    for (netlist.nodes.items) |node| {
        std.log.debug("node #{}", .{node.id});
        for (node.connected_terminals.items) |term| {
            std.log.debug("     {s}.{}", .{ components.items[term.component_id].name, term.terminal_id });
        }
    }
}
