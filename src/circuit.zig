const std = @import("std");

const component = @import("component.zig");
const renderer = @import("renderer.zig");
const global = @import("global.zig");
const matrix = @import("matrix.zig");

const dvui = @import("dvui");

pub const PlacementMode = enum {
    none,
    component,
    wire,
};

pub const GridPosition = struct {
    x: i32,
    y: i32,

    pub fn eql(self: GridPosition, other: GridPosition) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn toCircuitPosition(self: GridPosition, circuit_rect: dvui.Rect.Physical) dvui.Point {
        return dvui.Point{
            .x = circuit_rect.x + @as(f32, @floatFromInt(self.x * global.grid_size)),
            .y = circuit_rect.y + @as(f32, @floatFromInt(self.y * global.grid_size)),
        };
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

pub var held_component: component.Component.InnerType = .resistor;
pub var held_component_rotation: component.Component.Rotation = .right;

pub var held_wire_p1: ?GridPosition = null;

pub var components: std.array_list.Managed(component.Component) = undefined;
pub var wires: std.array_list.Managed(Wire) = undefined;

pub fn canPlaceComponent(
    comp_type: component.Component.InnerType,
    pos: GridPosition,
    rotation: component.Component.Rotation,
) bool {
    var buffer: [100]component.OccupiedGridPosition = undefined;
    const positions = comp_type.getOccupiedGridPositions(pos, rotation, buffer[0..]);
    for (components.items) |comp| {
        if (comp.intersects(positions)) return false;
    }

    var buffer2: [100]component.OccupiedGridPosition = undefined;
    for (wires.items) |wire| {
        const wire_positions = getOccupiedGridPositions(wire, buffer2[0..]);
        if (component.occupiedPointsIntersect(positions, wire_positions)) return false;
    }

    return true;
}

fn getOccupiedGridPositions(wire: Wire, occupied: []component.OccupiedGridPosition) []component.OccupiedGridPosition {
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
        occupied[i] = component.OccupiedGridPosition{
            .pos = pos,
            .terminal = true,
        };
    }

    return occupied[0..abs_len];
}

pub fn canPlaceWire(wire: Wire) bool {
    var buffer: [100]component.OccupiedGridPosition = undefined;
    const positions = getOccupiedGridPositions(wire, buffer[0..]);

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

pub fn gridPositionFromPos(circuit_rect: dvui.Rect.Physical, pos: dvui.Point.Physical) GridPosition {
    const rel_pos = pos.diff(circuit_rect.topLeft());

    var grid_pos = GridPosition{
        .x = @intFromFloat(@divTrunc(rel_pos.x, global.grid_size)),
        .y = @intFromFloat(@divTrunc(rel_pos.y, global.grid_size)),
    };

    if (@mod(rel_pos.x, global.grid_size) > global.grid_size / 2)
        grid_pos.x += 1;

    if (@mod(rel_pos.y, global.grid_size) > global.grid_size / 2)
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
        voltage: ?f32,
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
    var node_terminals = std.ArrayListUnmanaged(std.ArrayListUnmanaged(NetList.Terminal)){};
    defer node_terminals.deinit(allocator);

    var remaining_terminals = try getRemainingTerminals(allocator);
    defer remaining_terminals.deinit(allocator);

    try traverseWiresForNodes(allocator, &remaining_terminals, &node_terminals);
    try findAllDirectConnections(allocator, &remaining_terminals, &node_terminals);

    const nodes = try mergeGroundNodes(allocator, node_terminals.items);

    return NetList{
        .allocator = allocator,
        .nodes = nodes,
    };
}

fn mergeGroundNodes(
    allocator: std.mem.Allocator,
    node_terminals: []std.ArrayListUnmanaged(NetList.Terminal),
) !std.ArrayListUnmanaged(NetList.Node) {
    var nodes = std.ArrayListUnmanaged(NetList.Node){};

    // add ground node
    try nodes.append(allocator, NetList.Node{
        .id = 0,
        .connected_terminals = std.ArrayListUnmanaged(NetList.Terminal){},
        .voltage = null,
    });

    for (node_terminals) |*terminals| {
        if (nodeHasGround(terminals.items)) {
            // the terminals are added to the ground node's list of terminals
            // so we can deinit the list containing them
            for (terminals.items) |term| {
                components.items[term.component_id].terminal_node_ids[term.terminal_id] = 0;
                try nodes.items[0].connected_terminals.append(allocator, term);
            }
            terminals.deinit(allocator);
        } else {
            const node_id = nodes.items.len;
            // if the node doesnt have a GND component connected to it
            // then create its own node
            try nodes.append(allocator, NetList.Node{
                .id = node_id,
                .connected_terminals = terminals.*,
                .voltage = null,
            });
            for (terminals.items) |term| {
                components.items[term.component_id].terminal_node_ids[term.terminal_id] = node_id;
            }
        }
    }

    return nodes;
}

fn nodeHasGround(terminals: []const NetList.Terminal) bool {
    for (terminals) |term| {
        const comp = components.items[term.component_id];
        if (@as(component.Component.InnerType, comp.inner) == component.Component.InnerType.ground) {
            return true;
        }
    }

    return false;
}

fn getRemainingTerminals(allocator: std.mem.Allocator) !std.ArrayListUnmanaged(TerminalWithPos) {
    const terminal_count_approx = components.items.len * 2;
    var remaining_terminals = try std.ArrayListUnmanaged(TerminalWithPos).initCapacity(
        allocator,
        terminal_count_approx,
    );

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

    return remaining_terminals;
}

fn findAllDirectConnections(
    allocator: std.mem.Allocator,
    remaining_terminals: *std.ArrayListUnmanaged(TerminalWithPos),
    nodes: *std.ArrayListUnmanaged(std.ArrayListUnmanaged(NetList.Terminal)),
) !void {
    while (remaining_terminals.pop()) |selected_terminal| {
        var connected_terminals = std.ArrayListUnmanaged(NetList.Terminal){};
        try connected_terminals.append(allocator, selected_terminal.term);

        while (getLastConnected(selected_terminal.pos, remaining_terminals)) |other_term| {
            try connected_terminals.append(allocator, other_term.term);
        }
        try nodes.append(allocator, connected_terminals);
    }
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
    nodes: *std.ArrayListUnmanaged(std.ArrayListUnmanaged(NetList.Terminal)),
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

        try nodes.append(allocator, connected_terminals);
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

fn getLastConnected(
    pos: GridPosition,
    terms: *std.ArrayListUnmanaged(TerminalWithPos),
) ?TerminalWithPos {
    for (0..terms.items.len) |i| {
        if (pos.eql(terms.items[i].pos)) {
            // swapRemove should be safe to use here
            return terms.swapRemove(i);
        }
    }

    return null;
}

const MNA = struct {
    mat: matrix.Matrix(f32),
    nodes: []const NetList.Node,
    group_2: []const usize,

    fn init(
        allocator: std.mem.Allocator,
        nodes: []const NetList.Node,
        group_2: []const usize,
    ) !MNA {
        const total_variable_count = nodes.len - 1 + group_2.len;
        return MNA{
            .mat = try matrix.Matrix(f32).init(
                allocator,
                total_variable_count,
                total_variable_count + 1,
            ),
            .nodes = nodes,
            .group_2 = group_2,
        };
    }

    fn stampVoltageVoltage(
        self: *MNA,
        row_voltage_id: usize,
        col_voltage_id: usize,
        val: f32,
    ) void {
        // ignore grounds
        if (row_voltage_id == 0 or col_voltage_id == 0) return;
        self.mat.data[row_voltage_id - 1][col_voltage_id - 1] += val;
    }

    fn stampVoltageCurrent(
        self: *MNA,
        row_voltage_id: usize,
        col_current_id: usize,
        val: f32,
    ) void {
        // ignore grounds
        const col = self.nodes.len - 1 + col_current_id;
        if (row_voltage_id == 0) return;
        self.mat.data[row_voltage_id - 1][col] += val;
    }

    fn stampCurrentCurrent(
        self: *MNA,
        row_current_id: usize,
        col_current_id: usize,
        val: f32,
    ) void {
        const row = self.nodes.len - 1 + row_current_id;
        const col = self.nodes.len - 1 + col_current_id;
        self.mat.data[row][col] += val;
    }

    fn stampCurrentVoltage(
        self: *MNA,
        row_current_id: usize,
        col_voltage_id: usize,
        val: f32,
    ) void {
        // ignore ground
        if (col_voltage_id == 0) return;
        const row = self.nodes.len - 1 + row_current_id;
        self.mat.data[row][col_voltage_id - 1] += val;
    }

    fn stampVoltageRHS(self: *MNA, row_voltage_id: usize, val: f32) void {
        // ignore ground
        if (row_voltage_id == 0) return;
        self.mat.data[row_voltage_id - 1][self.mat.col_count - 1] = val;
    }

    fn stampCurrentRHS(self: *MNA, row_current_id: usize, val: f32) void {
        const row = self.nodes.len - 1 + row_current_id;
        self.mat.data[row][self.mat.col_count - 1] = val;
    }
};

fn createMNAMatrix(allocator: std.mem.Allocator, nodes: []const NetList.Node, group_2: []const usize) !MNA {
    // create matrix (|v| + |i2| X |v| + |i2| + 1)
    // where v is all nodes except ground
    // the last column is the RHS of the equation Ax=b
    // basically (A|b) where b is an (|v| + |i2| X 1) matrix

    const total_variable_count = nodes.len - 1 + group_2.len;

    var mna = try MNA.init(
        allocator,
        nodes,
        group_2,
    );

    for (0..total_variable_count) |row| {
        for (0..total_variable_count + 1) |col| {
            mna.mat.data[row][col] = 0;
        }
    }

    for (0.., components.items) |idx, comp| {
        switch (comp.inner) {
            .resistor => |r| {
                const in_group_2 = std.mem.indexOf(usize, group_2, &.{idx}) != null;

                const node_ids = comp.terminal_node_ids;
                const v_plus = node_ids[0];
                const v_minus = node_ids[1];

                const g = 1 / r;

                if (in_group_2) {} else {
                    mna.stampVoltageVoltage(v_plus, v_plus, g);
                    mna.stampVoltageVoltage(v_plus, v_minus, -g);
                    mna.stampVoltageVoltage(v_minus, v_plus, -g);
                    mna.stampVoltageVoltage(v_minus, v_minus, g);
                }
            },
            .voltage_source => |v| {
                const node_ids = comp.terminal_node_ids;
                const v_plus = node_ids[0];
                const v_minus = node_ids[1];

                const idx_in_group_2 = std.mem.indexOf(usize, group_2, &.{idx}) orelse @panic("Invalid Group 2");

                mna.stampVoltageCurrent(v_plus, idx_in_group_2, 1);
                mna.stampVoltageCurrent(v_minus, idx_in_group_2, -1);

                mna.stampCurrentVoltage(idx_in_group_2, v_plus, 1);
                mna.stampCurrentVoltage(idx_in_group_2, v_minus, -1);
                mna.stampCurrentRHS(idx_in_group_2, v);
            },
            .current_source => |i| {
                const in_group_2 = std.mem.indexOf(usize, group_2, &.{idx}) != null;

                const node_ids = comp.terminal_node_ids;
                const v_plus = node_ids[0];
                const v_minus = node_ids[1];

                if (in_group_2) {} else {
                    mna.stampVoltageRHS(v_plus, -i);
                    mna.stampVoltageRHS(v_minus, i);
                }
            },
            else => {},
        }
    }

    return mna;
}

fn printMNAMatrix(
    mat: *const matrix.Matrix(f32),
    nodes: []const NetList.Node,
    group_2: []const usize,
) void {
    const total_variable_count = nodes.len - 1 + group_2.len;
    std.debug.assert(mat.row_count == total_variable_count);
    std.debug.assert(mat.col_count == total_variable_count + 1);

    for (0..total_variable_count) |row| {
        if (row >= nodes.len - 1) {
            std.debug.print("i{}: ", .{group_2[row - (nodes.len - 1)]});
        } else {
            std.debug.print("v{}: ", .{row + 1});
        }

        for (0..total_variable_count) |col| {
            std.debug.print("{}", .{mat.data[row][col]});
            if (col >= nodes.len - 1) {
                std.debug.print("*i{} ", .{group_2[col - (nodes.len - 1)]});
            } else {
                std.debug.print("*v{} ", .{col + 1});
            }

            if (col != total_variable_count - 1) {
                std.debug.print(" + ", .{});
            }
        }

        std.debug.print("= {}", .{mat.data[row][total_variable_count]});

        std.debug.print("\n", .{});
    }
}

pub fn analyse(allocator: std.mem.Allocator) void {
    // group edges:
    // - group 1(i1): all elements whose current will be eliminated
    // - group 2(i2): all other elements

    // since we include all nodes, theres no need to explicitly store their order
    // however we store i2 elements

    var group_2 = std.ArrayListUnmanaged(usize){};
    defer group_2.deinit(allocator);

    // TODO: include currents that are control variables
    // TODO: include currents that we want to inspect
    for (0.., components.items) |idx, comp| {
        switch (comp.inner) {
            .voltage_source => {
                group_2.append(allocator, idx) catch {
                    std.log.err("Failed to build netlist", .{});
                    return;
                };
            },
            else => {},
        }
    }

    var netlist = buildNetList(allocator) catch {
        std.log.err("Failed to build netlist", .{});
        return;
    };
    defer netlist.deinit();

    // create matrix (|v| + |i2| X |v| + |i2| + 1)
    // iterate over all elements and stamp them onto the matrix
    var mna = createMNAMatrix(allocator, netlist.nodes.items, group_2.items) catch {
        std.log.err("Failed to build netlist", .{});
        return;
    };
    mna.mat.dump();
    printMNAMatrix(&mna.mat, netlist.nodes.items, group_2.items);

    // solve the matrix with Gauss elimination
    mna.mat.gaussJordanElimination();
    mna.mat.dump();
    printMNAMatrix(&mna.mat, netlist.nodes.items, group_2.items);
}
