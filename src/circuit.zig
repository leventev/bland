const std = @import("std");

const component = @import("component.zig");
const renderer = @import("renderer.zig");
const global = @import("global.zig");
const matrix = @import("matrix.zig");

const dvui = @import("dvui");
const SDLBackend = dvui.backend;
comptime {
    std.debug.assert(@hasDecl(SDLBackend, "SDLBackend"));
}
const sdl = SDLBackend.c;

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

pub var held_component: component.Component.InnerType = .resistor;
pub var held_component_rotation: component.Component.Rotation = .right;

pub var held_wire_p1: ?GridPosition = null;

pub var components: std.ArrayList(component.Component) = undefined;
pub var wires: std.ArrayList(Wire) = undefined;

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

pub fn gridPositionFromMouse() GridPosition {
    var mouse_x_tmp: f32 = undefined;
    var mouse_y_tmp: f32 = undefined;
    _ = sdl.SDL_GetMouseState(&mouse_x_tmp, &mouse_y_tmp);

    const mouse_x = @as(i32, @intFromFloat(mouse_x_tmp));
    const mouse_y = @as(i32, @intFromFloat(mouse_y_tmp));

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

    var nodes = try mergeGroundNodes(allocator, node_terminals.items);

    setKnownVoltages(&nodes);

    return NetList{
        .allocator = allocator,
        .nodes = nodes,
    };
}

fn checkForKnownVoltage(nodes: *std.ArrayListUnmanaged(NetList.Node)) bool {
    for (nodes.items) |*node| {
        if (node.voltage != null) continue;

        for (node.connected_terminals.items) |term| {
            const comp = components.items[term.component_id];
            if (@as(component.Component.InnerType, comp.inner) != component.Component.InnerType.voltage_source)
                continue;

            const pos_node_id = comp.terminal_node_ids[0];
            const neg_node_id = comp.terminal_node_ids[1];
            const add = pos_node_id == node.id;
            const other_node_id = if (add) neg_node_id else pos_node_id;

            const other_node = nodes.items[other_node_id];
            if (other_node.voltage) |other_voltage| {
                // TODO: polarity
                const voltage = comp.inner.voltage_source;
                node.voltage = other_voltage + if (add) voltage else -voltage;
                return true;
            }
        }
    }
    return false;
}

fn setKnownVoltages(nodes: *std.ArrayListUnmanaged(NetList.Node)) void {
    nodes.items[0].voltage = 0;
    while (checkForKnownVoltage(nodes)) {}
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

const Supernode = struct {
    // node ids
    nodes: std.ArrayListUnmanaged(usize),
    // component ids
    voltage_sources: std.ArrayListUnmanaged(usize),
};

const NodeGroup = union(enum) {
    single: usize,
    supernode: Supernode,
};

fn getNodeGroup(
    allocator: std.mem.Allocator,
    nodes: []const NetList.Node,
    start_node_id: usize,
) !NodeGroup {
    var node_group = std.ArrayListUnmanaged(usize){};
    var voltage_sources = std.ArrayListUnmanaged(usize){};

    var node_queue = try std.ArrayListUnmanaged(usize).initCapacity(allocator, 4);
    defer node_queue.deinit(allocator);

    try node_queue.append(allocator, start_node_id);

    while (node_queue.pop()) |node_id| {
        const node = nodes[node_id];

        // if there is a voltage source connected to a node with a known voltage
        // then we dont need to use a supernode
        if (node.voltage != null) {
            node_group.deinit(allocator);
            return NodeGroup{ .single = start_node_id };
        }

        try node_group.append(allocator, node.id);

        for (node.connected_terminals.items) |terminal| {
            const comp = components.items[terminal.component_id];
            switch (comp.inner) {
                else => continue,
                .voltage_source => {
                    // skip voltage sources already added
                    var found = false;
                    for (voltage_sources.items) |vs_id| {
                        if (vs_id == terminal.component_id) {
                            found = true;
                            break;
                        }
                    }
                    if (found) continue;

                    const other_node_id = comp.otherNode(node.id);

                    try node_queue.append(allocator, other_node_id);
                    try voltage_sources.append(allocator, terminal.component_id);
                },
            }
        }
    }

    return NodeGroup{ .supernode = .{
        .nodes = node_group,
        .voltage_sources = voltage_sources,
    } };
}

fn findSupernodes(
    allocator: std.mem.Allocator,
    nodes: []const NetList.Node,
) !std.ArrayListUnmanaged(NodeGroup) {
    var nodes_remaining = try allocator.alloc(bool, nodes.len);
    defer allocator.free(nodes_remaining);

    var node_groups = std.ArrayListUnmanaged(NodeGroup){};

    for (0..nodes_remaining.len) |i| {
        nodes_remaining[i] = true;
    }

    // TODO: implement a more optimal solution
    // the current implementation keeps allocating and deallocating a buffer
    // and traverses the same node multiple times
    // a better solution would be finding all voltage source "groups" first
    // and then checking whether any node connected to it has a known voltage
    // if yes then calculate the voltages of all other nodes
    // if not then we have to use the supernode technique
    // but as this is not a performance critical code segment
    // this has low priority

    for (0..nodes_remaining.len) |i| {
        if (!nodes_remaining[i]) continue;

        const current_node = nodes[i];
        // if the node voltage is known the node is normal
        if (current_node.voltage != null) {
            try node_groups.append(allocator, NodeGroup{ .single = i });
            nodes_remaining[i] = false;
        } else {
            const group = try getNodeGroup(allocator, nodes, i);
            try node_groups.append(allocator, group);
            switch (group) {
                .single => |node_id| {
                    nodes_remaining[node_id] = false;
                },
                .supernode => |supernode| {
                    for (supernode.nodes.items) |node_id| {
                        nodes_remaining[node_id] = false;
                    }
                },
            }
        }
    }

    return node_groups;
}

fn addEquationToRow(
    nodes: []const NetList.Node,
    mat: *matrix.Matrix(f32),
    current_row: usize,
    node_id: usize,
) void {
    const node = nodes[node_id];

    var total_conductance: f32 = 0;

    for (node.connected_terminals.items) |terminal| {
        const comp = components.items[terminal.component_id];
        switch (comp.inner) {
            .resistor => |resistance| {
                const conductance = 1 / resistance;
                total_conductance += conductance;

                const other_node_id = comp.otherNode(node_id);

                // set the coefficient for the other node
                // we add the conductance instead of just setting it
                // because of parallel resistances
                mat.data[current_row][other_node_id] += -conductance;
            },
            else => continue,
        }
    }

    // set the coefficient for the current node
    mat.data[current_row][node.id] = total_conductance;
}

fn addSingleNodeToAugmentedMatrix(
    nodes: []const NetList.Node,
    mat: *matrix.Matrix(f32),
    current_row: usize,
    node_id: usize,
) void {
    const node = nodes[node_id];

    if (node.voltage) |voltage| {
        // set the coefficient associated with the node to 1
        // and the rightmost column to the known voltage
        // all other columns are 0
        mat.data[current_row][node_id] = 1;
        mat.data[current_row][nodes.len] = voltage;
    } else {
        addEquationToRow(nodes, mat, current_row, node_id);
    }
}

fn addSupernodeToAugmentedMatrix(
    nodes: []const NetList.Node,
    mat: *matrix.Matrix(f32),
    current_row: usize,
    supernode: Supernode,
) void {
    std.log.debug("add supernode {} {} {}", .{
        current_row,
        supernode.nodes.items.len,
        supernode.voltage_sources.items.len,
    });
    // add all equations to the same row
    for (supernode.nodes.items) |node_id| {
        addEquationToRow(nodes, mat, current_row, node_id);
    }
    for (0.., supernode.voltage_sources.items) |i, comp_id| {
        const row = current_row + 1 + i;

        const comp = components.items[comp_id];
        const positive_node = comp.terminal_node_ids[0];
        const negative_node = comp.terminal_node_ids[1];

        for (0..nodes.len) |col| {
            mat.data[row][col] = 0;
        }
        mat.data[row][positive_node] = 1;
        mat.data[row][negative_node] = -1;
        mat.data[row][nodes.len] = comp.inner.voltage_source;
    }
}

fn constructAugmentedMatrix(
    allocator: std.mem.Allocator,
    nodes: []const NetList.Node,
) !matrix.Matrix(f32) {
    var mat = try matrix.Matrix(f32).init(
        allocator,
        nodes.len,
        nodes.len + 1,
    );

    for (0..nodes.len) |row| {
        for (0..nodes.len + 1) |col| {
            mat.data[row][col] = 0;
        }
    }

    var node_groups = try findSupernodes(allocator, nodes);
    defer {
        for (node_groups.items) |*node_group| {
            switch (node_group.*) {
                .supernode => |*supernode| {
                    supernode.nodes.deinit(allocator);
                    supernode.voltage_sources.deinit(allocator);
                },
                else => {},
            }
        }
        node_groups.deinit(allocator);
    }

    var current_row: usize = 0;

    for (node_groups.items) |node_group| {
        switch (node_group) {
            .single => |node_id| {
                addSingleNodeToAugmentedMatrix(nodes, &mat, current_row, node_id);
                current_row += 1;
            },
            .supernode => |supernode| {
                addSupernodeToAugmentedMatrix(nodes, &mat, current_row, supernode);
                current_row += supernode.nodes.items.len;
            },
        }
    }

    return mat;
}

pub fn analyse(allocator: std.mem.Allocator) void {
    var netlist = buildNetList(allocator) catch {
        std.log.err("Failed to build netlist", .{});
        return;
    };
    defer netlist.deinit();

    var unknown_count: usize = 0;
    for (netlist.nodes.items) |node| {
        if (node.voltage) |voltage| {
            std.log.debug("node #{} {}V", .{ node.id, voltage });
        } else {
            unknown_count += 1;
            std.log.debug("node #{}", .{node.id});
        }
        for (node.connected_terminals.items) |term| {
            std.log.debug("     {s}.{}", .{ components.items[term.component_id].name, term.terminal_id });
        }
    }

    var augmented_matrix = constructAugmentedMatrix(allocator, netlist.nodes.items) catch {
        std.log.err("Failed to construct augmented matrix", .{});
        return;
    };
    defer augmented_matrix.deinit(allocator);

    augmented_matrix.dump();

    augmented_matrix.gaussJordanElimination();

    for (0..netlist.nodes.items.len) |i| {
        const voltage = augmented_matrix.data[i][netlist.nodes.items.len];
        netlist.nodes.items[i].voltage = voltage;
        std.log.debug("node #{} voltage: {}V", .{ i, voltage });
    }

    for (components.items) |comp| {
        switch (comp.inner) {
            .resistor => |resistance| {
                const node1 = netlist.nodes.items[comp.terminal_node_ids[0]];
                const node2 = netlist.nodes.items[comp.terminal_node_ids[1]];
                const voltage = node2.voltage.? - node1.voltage.?;
                const current = @abs(voltage / resistance);
                std.log.debug("{s} current: {}A", .{ comp.name, current });
            },
            else => {},
        }
    }
}
