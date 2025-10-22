const std = @import("std");

const component = @import("component.zig");
const renderer = @import("renderer.zig");
const global = @import("global.zig");
const matrix = @import("matrix.zig");

const dvui = @import("dvui");

pub const FloatType = f64;

pub const PlacementMode = enum {
    none,
    component,
    wire,
    pin,
};

pub const Rotation = enum {
    right,
    bottom,
    left,
    top,

    pub fn rotateClockwise(self: Rotation) Rotation {
        return switch (self) {
            .right => .bottom,
            .bottom => .left,
            .left => .top,
            .top => .right,
        };
    }
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
pub var placement_rotation: Rotation = .right;

pub var held_wire_p1: ?GridPosition = null;

fn getOccupiedGridPositions(
    wire: Wire,
    occupied: []component.OccupiedGridPosition,
) []component.OccupiedGridPosition {
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

pub fn gridPositionFromPos(
    circuit_rect: dvui.Rect.Physical,
    pos: dvui.Point.Physical,
) GridPosition {
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
pub const NetList = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayListUnmanaged(Node),
    components: std.ArrayListUnmanaged(Component),

    pub const ground_node_id = 0;

    pub const Terminal = struct {
        component_id: usize,
        terminal_id: usize,
    };

    pub const Node = struct {
        id: usize,
        connected_terminals: std.ArrayListUnmanaged(Terminal),
        voltage: ?FloatType,
    };

    pub const Component = struct {
        inner: component.Component.Inner,
        name: []const u8,
        // TODO: this is a duplicate since we already store the terminal nodes
        // connected to the nodes
        terminal_node_ids: []const usize,
    };

    pub fn init(allocator: std.mem.Allocator) !NetList {
        var nodes = std.ArrayListUnmanaged(Node){};
        try nodes.append(allocator, .{
            .id = ground_node_id,
            .connected_terminals = std.ArrayListUnmanaged(Terminal){},
            .voltage = 0,
        });

        return NetList{
            .allocator = allocator,
            .nodes = nodes,
            .components = std.ArrayList(NetList.Component){},
        };
    }

    pub fn allocateNode(self: *NetList) !usize {
        const next_id = self.nodes.items.len;
        try self.nodes.append(self.allocator, .{
            .id = next_id,
            .connected_terminals = std.ArrayListUnmanaged(Terminal){},
            .voltage = null,
        });

        return next_id;
    }

    //pub fn addComponentNoConnection(self: *NetList, inner: component.Component.Inner) !usize {
    //    const id = self.components.items.len;
    //    try self.components.append(self.allocator, comp);
    //    return id;
    //}

    pub fn addComponent(
        self: *NetList,
        inner: component.Component.Inner,
        name: []const u8,
        node_ids: []const usize,
    ) !usize {
        const id = self.components.items.len;
        try self.components.append(self.allocator, NetList.Component{
            .inner = inner,
            .name = try self.allocator.dupe(u8, name),
            .terminal_node_ids = try self.allocator.dupe(usize, node_ids),
        });
        for (node_ids, 0..) |node_id, term_id| {
            try self.addComponentConnection(node_id, id, term_id);
        }
        return id;
    }

    pub fn addComponentConnection(
        self: *NetList,
        node_id: usize,
        comp_id: usize,
        term_id: usize,
    ) !void {
        // TODO: error instead of assert
        std.debug.assert(node_id < self.nodes.items.len);
        std.debug.assert(comp_id < self.components.items.len);

        try self.nodes.items[node_id].connected_terminals.append(
            self.allocator,
            NetList.Terminal{
                .component_id = comp_id,
                .terminal_id = term_id,
            },
        );
    }

    pub fn deinit(self: *NetList) void {
        for (self.nodes.items) |*node| {
            node.connected_terminals.deinit(self.allocator);
        }

        for (self.components.items) |comp| {
            self.allocator.free(comp.name);
            self.allocator.free(comp.terminal_node_ids);
        }

        self.nodes.deinit(self.allocator);
        self.components.deinit(self.allocator);
        self.* = undefined;
    }

    fn fromCircuit(circuit: *const Circuit) !NetList {
        var node_terminals = std.ArrayListUnmanaged(
            std.ArrayListUnmanaged(NetList.Terminal),
        ){};
        defer node_terminals.deinit(circuit.allocator);

        var remaining_terminals = try circuit.getAllTerminals();
        defer remaining_terminals.deinit();

        try circuit.traverseWiresForNodes(
            &remaining_terminals,
            &node_terminals,
        );

        try findAllDirectConnections(
            circuit.allocator,
            &remaining_terminals,
            &node_terminals,
        );

        const nodes = try circuit.mergeGroundNodes(
            node_terminals.items,
        );

        var netlist_comps = try std.ArrayList(NetList.Component).initCapacity(
            circuit.allocator,
            circuit.components.items.len,
        );

        for (circuit.components.items) |comp| {
            try netlist_comps.append(circuit.allocator, .{
                .inner = comp.inner,
                .name = try circuit.allocator.dupe(u8, comp.name),
                .terminal_node_ids = try circuit.allocator.dupe(usize, &comp.terminal_node_ids),
            });
        }

        return NetList{
            .allocator = circuit.allocator,
            .nodes = nodes,
            .components = netlist_comps,
        };
    }

    // TODO: instead of group 2 pass the components whose
    // currents are included in group 2
    // since we will add currents used by CCVS, etc later too
    // so the name group_2 is misleading
    fn createMNAMatrix(self: *const NetList, group_2: []const usize) !MNA {
        // create matrix (|v| + |i2| X |v| + |i2| + 1)
        // where v is all nodes except ground
        // the last column is the RHS of the equation Ax=b
        // basically (A|b) where b is an (|v| + |i2| X 1) matrix

        const total_variable_count = self.nodes.items.len - 1 + group_2.len;

        var mna = try MNA.init(
            self.allocator,
            self.nodes.items,
            group_2,
        );

        for (0..total_variable_count) |row| {
            for (0..total_variable_count + 1) |col| {
                mna.mat.data[row][col] = 0;
            }
        }

        for (0.., self.components.items) |idx, comp| {
            const current_group_2_idx = std.mem.indexOf(usize, group_2, &.{idx});
            comp.inner.stampMatrix(comp.terminal_node_ids, &mna, current_group_2_idx);
        }

        return mna;
    }

    pub const AnalysationResult = struct {
        voltages: []FloatType,
        currents: []?FloatType,

        pub fn deinit(self: *AnalysationResult, allocator: std.mem.Allocator) void {
            allocator.free(self.voltages);
            allocator.free(self.currents);
        }
    };

    pub fn analyse(self: *const NetList, currents_watched: []const usize) !AnalysationResult {
        // group edges:
        // - group 1(i1): all elements whose current will be eliminated
        // - group 2(i2): all other elements

        // since we include all nodes, theres no need to explicitly store their order
        // however we store i2 elements

        var group_2 = std.ArrayListUnmanaged(usize){};
        try group_2.appendSlice(self.allocator, currents_watched);
        defer group_2.deinit(self.allocator);

        // TODO: include currents that are control variables
        for (0.., self.components.items) |idx, comp| {
            var already_in = false;
            for (group_2.items) |group_2_comp_id| {
                if (group_2_comp_id == idx) {
                    already_in = true;
                    break;
                }
            }

            if (already_in) continue;

            switch (comp.inner) {
                .voltage_source => {
                    group_2.append(self.allocator, idx) catch {
                        @panic("Failed to build netlist");
                    };
                },
                else => {},
            }
        }

        // create matrix (|v| + |i2| X |v| + |i2| + 1)
        // iterate over all elements and stamp them onto the matrix
        var mna = self.createMNAMatrix(group_2.items) catch {
            @panic("Failed to build netlist");
        };
        defer mna.deinit(self.allocator);
        //mna.mat.dump();
        //mna.print(self.nodes.items, group_2.items);

        // solve the matrix with Gauss elimination
        mna.mat.gaussJordanElimination();
        //mna.mat.dump();
        //mna.print(self.nodes.items, group_2.items);

        var res = AnalysationResult{
            .voltages = try self.allocator.alloc(
                FloatType,
                self.nodes.items.len,
            ),
            .currents = try self.allocator.alloc(
                ?FloatType,
                self.components.items.len,
            ),
        };

        res.voltages[0] = 0;
        for (1..self.nodes.items.len) |i| {
            res.voltages[i] = mna.mat.data[i - 1][mna.mat.col_count - 1];
        }

        // null out currents
        for (0..self.components.items.len) |i| {
            res.currents[i] = null;
        }

        for (group_2.items, 0..) |current_idx, i| {
            res.currents[current_idx] = mna.mat.data[self.nodes.items.len + i - 1][mna.mat.col_count - 1];
        }

        return res;
    }
};

const TerminalWithPos = struct {
    term: NetList.Terminal,
    pos: GridPosition,
};

pub var main_circuit: Circuit = undefined;

pub const Circuit = struct {
    allocator: std.mem.Allocator,
    components: std.ArrayList(component.Component),
    wires: std.ArrayList(Wire),

    fn getAllTerminals(self: *const Circuit) !std.array_list.Managed(TerminalWithPos) {
        const terminal_count_approx = self.components.items.len * 2;
        var terminals = try std.array_list.Managed(TerminalWithPos).initCapacity(
            self.allocator,
            terminal_count_approx,
        );

        for (self.components.items, 0..) |comp, comp_id| {
            // TODO: get terminal count for specific component
            var buffer: [16]GridPosition = undefined;
            const comp_terminals = comp.terminals(buffer[0..]);
            for (comp_terminals, 0..) |pos, term_id| {
                try terminals.append(TerminalWithPos{
                    .term = NetList.Terminal{
                        .component_id = comp_id,
                        .terminal_id = term_id,
                    },
                    .pos = pos,
                });
            }
        }

        return terminals;
    }

    // TODO: optimize this although i doubt this has a non negligible performance impact
    fn traverseWiresForNodes(
        self: *const Circuit,
        remaining_terminals: *std.array_list.Managed(TerminalWithPos),
        nodes: *std.ArrayListUnmanaged(std.ArrayListUnmanaged(NetList.Terminal)),
    ) !void {
        var connected_wire_buffer = try self.allocator.alloc(usize, self.wires.items.len);
        defer self.allocator.free(connected_wire_buffer);

        var remaining_wires = try self.allocator.dupe(Wire, self.wires.items);
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
                    try connected_terminals.append(self.allocator, term);
                }
            }

            rem = remaining_wires.len - connected_wires.len;
            if (rem == 0) {
                self.allocator.free(remaining_wires);
            } else {
                var new_remaining_wires = try self.allocator.alloc(Wire, rem);
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
                self.allocator.free(remaining_wires);
                remaining_wires = new_remaining_wires;
            }

            try nodes.append(self.allocator, connected_terminals);
        }
    }

    fn mergeGroundNodes(
        self: *const Circuit,
        node_terminals: []std.ArrayListUnmanaged(NetList.Terminal),
    ) !std.ArrayListUnmanaged(NetList.Node) {
        var nodes = std.ArrayListUnmanaged(NetList.Node){};

        // add ground node
        try nodes.append(self.allocator, NetList.Node{
            .id = 0,
            .connected_terminals = std.ArrayListUnmanaged(NetList.Terminal){},
            .voltage = null,
        });

        for (node_terminals) |*terminals| {
            if (self.nodeHasGround(terminals.items)) {
                // the terminals are added to the ground node's list of terminals
                // so we can deinit the list containing them
                for (terminals.items) |term| {
                    self.components.items[term.component_id].terminal_node_ids[term.terminal_id] = 0;
                    try nodes.items[0].connected_terminals.append(self.allocator, term);
                }
                terminals.deinit(self.allocator);
            } else {
                // if the node doesnt have a GND component connected to it
                // then create its own node
                const node_id = nodes.items.len;
                try nodes.append(self.allocator, NetList.Node{
                    .id = node_id,
                    .connected_terminals = terminals.*,
                    .voltage = null,
                });
                for (terminals.items) |term| {
                    self.components.items[term.component_id].terminal_node_ids[term.terminal_id] = node_id;
                }
            }
        }

        return nodes;
    }

    fn nodeHasGround(self: *const Circuit, terminals: []const NetList.Terminal) bool {
        for (terminals) |term| {
            const comp = self.components.items[term.component_id];
            const comp_type = @as(component.Component.InnerType, comp.inner);
            if (comp_type == component.Component.InnerType.ground) {
                return true;
            }
        }

        return false;
    }

    pub fn canPlaceWire(self: *const Circuit, wire: Wire) bool {
        var buffer: [100]component.OccupiedGridPosition = undefined;
        const positions = getOccupiedGridPositions(wire, buffer[0..]);

        for (self.components.items) |comp| {
            if (comp.intersects(positions)) return false;
        }

        for (self.wires.items) |other_wire| {
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

    pub fn canPlaceComponent(
        self: *const Circuit,
        comp_type: component.Component.InnerType,
        pos: GridPosition,
        rotation: Rotation,
    ) bool {
        var buffer: [100]component.OccupiedGridPosition = undefined;
        const positions = comp_type.getOccupiedGridPositions(pos, rotation, buffer[0..]);
        for (self.components.items) |comp| {
            if (comp.intersects(positions)) return false;
        }

        var buffer2: [100]component.OccupiedGridPosition = undefined;
        for (self.wires.items) |wire| {
            const wire_positions = getOccupiedGridPositions(wire, buffer2[0..]);
            if (component.occupiedPointsIntersect(positions, wire_positions)) return false;
        }

        return true;
    }

    pub fn analyse(circuit: *const Circuit) void {
        var netlist = NetList.fromCircuit(circuit) catch {
            std.log.err("Failed to build netlist", .{});
            return;
        };
        defer netlist.deinit();

        _ = netlist.analyse(&.{}) catch {
            @panic("TODO");
        };
    }
};

fn findAllDirectConnections(
    allocator: std.mem.Allocator,
    remaining_terminals: *std.array_list.Managed(TerminalWithPos),
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
    remaining_terminals: *std.array_list.Managed(TerminalWithPos),
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

fn getDirectlyConnectedWires(
    ws: []const Wire,
    wire_id: usize,
    already_found_wires: []usize,
    connected_wires: []usize,
) []usize {
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
    terms: *std.array_list.Managed(TerminalWithPos),
) ?TerminalWithPos {
    for (0..terms.items.len) |i| {
        if (pos.eql(terms.items[i].pos)) {
            // swapRemove should be safe to use here
            return terms.swapRemove(i);
        }
    }

    return null;
}

pub const MNA = struct {
    mat: matrix.Matrix(FloatType),
    nodes: []const NetList.Node,
    group_2: []const usize,

    fn init(
        allocator: std.mem.Allocator,
        nodes: []const NetList.Node,
        group_2: []const usize,
    ) !MNA {
        const total_variable_count = nodes.len - 1 + group_2.len;
        return MNA{
            .mat = try matrix.Matrix(FloatType).init(
                allocator,
                total_variable_count,
                total_variable_count + 1,
            ),
            .nodes = nodes,
            .group_2 = group_2,
        };
    }

    pub fn deinit(self: *MNA, allocator: std.mem.Allocator) void {
        self.mat.deinit(allocator);
    }

    pub fn stampVoltageVoltage(
        self: *MNA,
        row_voltage_id: usize,
        col_voltage_id: usize,
        val: FloatType,
    ) void {
        // ignore grounds
        if (row_voltage_id == 0 or col_voltage_id == 0) return;
        self.mat.data[row_voltage_id - 1][col_voltage_id - 1] += val;
    }

    pub fn stampVoltageCurrent(
        self: *MNA,
        row_voltage_id: usize,
        col_current_id: usize,
        val: FloatType,
    ) void {
        // ignore grounds
        const col = self.nodes.len - 1 + col_current_id;
        if (row_voltage_id == 0) return;
        self.mat.data[row_voltage_id - 1][col] += val;
    }

    pub fn stampCurrentCurrent(
        self: *MNA,
        row_current_id: usize,
        col_current_id: usize,
        val: FloatType,
    ) void {
        const row = self.nodes.len - 1 + row_current_id;
        const col = self.nodes.len - 1 + col_current_id;
        self.mat.data[row][col] += val;
    }

    pub fn stampCurrentVoltage(
        self: *MNA,
        row_current_id: usize,
        col_voltage_id: usize,
        val: FloatType,
    ) void {
        // ignore ground
        if (col_voltage_id == 0) return;
        const row = self.nodes.len - 1 + row_current_id;
        self.mat.data[row][col_voltage_id - 1] += val;
    }

    pub fn stampVoltageRHS(self: *MNA, row_voltage_id: usize, val: FloatType) void {
        // ignore ground
        if (row_voltage_id == 0) return;
        self.mat.data[row_voltage_id - 1][self.mat.col_count - 1] = val;
    }

    pub fn stampCurrentRHS(self: *MNA, row_current_id: usize, val: FloatType) void {
        const row = self.nodes.len - 1 + row_current_id;
        self.mat.data[row][self.mat.col_count - 1] = val;
    }

    fn print(
        self: *const MNA,
        nodes: []const NetList.Node,
        group_2: []const usize,
    ) void {
        const mat = self.mat;
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
};

const tolerance = 1e-6;

fn checkCurrent(
    res: *const NetList.AnalysationResult,
    current_id: usize,
    expected: FloatType,
) !void {
    // TODO: check polarity???
    try std.testing.expect(current_id < res.currents.len);
    try std.testing.expect(res.currents[current_id] != null);
    const actual = res.currents[current_id].?;

    const expected_abs = @abs(expected);
    const expected_actual = @abs(actual);
    try std.testing.expectApproxEqRel(expected_abs, expected_actual, tolerance);
}

fn checkVoltage(
    res: *const NetList.AnalysationResult,
    voltage_id: usize,
    expected: FloatType,
) !void {
    try std.testing.expect(voltage_id < res.voltages.len);
    const actual = res.voltages[voltage_id];
    try std.testing.expectApproxEqRel(expected, actual, tolerance);
}

test "single resistor" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit();

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode();

    const v1 = 11.46;
    const r1 = 34.6898;

    const v1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .voltage_source = v1 },
        "V1",
        &.{ vs_plus_id, gnd_id },
    );

    const r1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .resistor = r1 },
        "R1",
        &.{ vs_plus_id, gnd_id },
    );

    var res = try netlist.analyse(&.{ v1_comp_idx, r1_comp_idx });
    defer res.deinit(netlist.allocator);

    // currents
    const current = v1 / r1;
    try checkCurrent(&res, v1_comp_idx, current);
    try checkCurrent(&res, r1_comp_idx, current);

    // voltages
    try checkVoltage(&res, gnd_id, 0);
    try checkVoltage(&res, vs_plus_id, v1);
}

test "voltage divider" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit();

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode();
    const middle_id = try netlist.allocateNode();

    const v1 = 5.0;
    const r1 = 24.5;
    const r2 = 343.5;

    const v1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .voltage_source = v1 },
        "V1",
        &.{ vs_plus_id, gnd_id },
    );

    const r1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .resistor = r1 },
        "R1",
        &.{ middle_id, vs_plus_id },
    );

    const r2_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .resistor = r2 },
        "R2",
        &.{ gnd_id, middle_id },
    );

    var res = try netlist.analyse(&.{ v1_comp_idx, r1_comp_idx, r2_comp_idx });
    defer res.deinit(netlist.allocator);

    // currents
    const current = v1 / (r1 + r2);
    try checkCurrent(&res, v1_comp_idx, current);
    try checkCurrent(&res, r1_comp_idx, current);
    try checkCurrent(&res, r2_comp_idx, current);

    // voltages
    try checkVoltage(&res, gnd_id, 0);
    try checkVoltage(&res, vs_plus_id, v1);
    const middle_node_voltage = v1 * (r2 / (r1 + r2));
    try checkVoltage(&res, middle_id, middle_node_voltage);
}
