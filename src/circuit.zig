const std = @import("std");
const bland = @import("bland");
const component = @import("component.zig");
const renderer = @import("renderer.zig");
const global = @import("global.zig");
const dvui = @import("dvui");

const NetList = bland.NetList;

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

pub const AnalysisReport = struct {
    component_names: []?[]const u8,
    node_count: usize,
    result: Result,
    pinned_nodes: []GraphicCircuit.PinnedNode,

    pub const Result = union(enum) {
        dc: NetList.RealAnalysisResult,
        frequency_sweep: NetList.FrequencySweepResult,
        transient: NetList.TransientResult,
    };
};

pub var analysis_reports: std.ArrayList(AnalysisReport) = .{};

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

    pub fn hovered(
        self: Wire,
        circuit_rect: dvui.Rect.Physical,
        mouse_pos: dvui.Point.Physical,
    ) bool {
        const tolerance = 12;

        switch (self.direction) {
            .horizontal => {
                const start_pos = self.pos.toCircuitPosition(circuit_rect);
                const end_pos = self.end().toCircuitPosition(circuit_rect);

                const left = if (end_pos.x > start_pos.x) start_pos else end_pos;
                const right = if (end_pos.x > start_pos.x) end_pos else start_pos;

                return @abs(mouse_pos.y - start_pos.y) < tolerance and mouse_pos.x >= left.x and mouse_pos.x <= right.x;
            },
            .vertical => {
                const start_pos = self.pos.toCircuitPosition(circuit_rect);
                const end_pos = self.end().toCircuitPosition(circuit_rect);

                const top = if (end_pos.y > start_pos.y) start_pos else end_pos;
                const bottom = if (end_pos.y > start_pos.y) end_pos else start_pos;

                return @abs(mouse_pos.x - start_pos.x) < tolerance and mouse_pos.y >= top.y and mouse_pos.y <= bottom.y;
            },
        }
    }
};

pub const PlacementModeType = enum {
    none,
    new_component,
    new_wire,
    new_pin,
    dragging_component,
    dragging_wire,
    dragging_pin,
};

pub const Element = union(enum) {
    component: usize,
    wire: usize,
    pin: usize,
};

pub const PlacementMode = union(PlacementModeType) {
    none: struct {
        hovered_element: ?Element,
    },
    new_component: struct {
        device_type: bland.Component.DeviceType,
    },
    new_wire: struct {
        held_wire_p1: ?GridPosition = null,
    },
    new_pin: void,
    dragging_component: struct {
        comp_id: usize,
    },
    dragging_wire: struct {
        wire_id: usize,
        offset: f32,
    },
    dragging_pin: struct {
        pin_id: usize,
    },
};

pub var placement_mode: PlacementMode = .{
    .none = .{ .hovered_element = null },
};

pub var placement_rotation: Rotation = .right;

// set to null on release
pub var mb1_click_pos: ?dvui.Point.Physical = null;

pub var selection: ?Element = null;
pub var selection_changed: bool = false;

pub fn delete() void {
    if (selection) |selected| {
        switch (selected) {
            .component => |comp_id| {
                main_circuit.deleteComponent(comp_id);
            },
            .wire => |wire_id| {
                main_circuit.deleteWire(wire_id);
            },
            .pin => |pin_id| {
                main_circuit.deletePin(pin_id);
            },
        }
        selection = null;
    }
}

fn getOccupiedGridPositions(
    wire: Wire,
    occupied: []component.OccupiedGridPosition,
) []component.OccupiedGridPosition {
    const abs_len = @abs(wire.length);
    const point_count = abs_len + 1;
    std.debug.assert(point_count < occupied.len);
    const negative = wire.length < 0;

    for (0..point_count) |i| {
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

    return occupied[0..point_count];
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

const TerminalWithPos = struct {
    term: NetList.Terminal,
    pos: GridPosition,
};

pub var main_circuit: GraphicCircuit = undefined;

pub var pin_counter: usize = 1;

pub const GraphicCircuit = struct {
    allocator: std.mem.Allocator,
    graphic_components: std.ArrayList(component.GraphicComponent),
    wires: std.ArrayList(Wire),
    pins: std.ArrayList(Pin),

    const max_pin_name_lengh = bland.component.max_component_name_length;

    pub const Pin = struct {
        pos: GridPosition,
        rotation: Rotation,
        name_buffer: []u8,
        // name is a slice into name_buffer
        name: []const u8,

        pub fn init(gpa: std.mem.Allocator, pos: GridPosition, rotation: Rotation) !Pin {
            var pin = Pin{
                .pos = pos,
                .rotation = rotation,
                .name_buffer = try gpa.alloc(u8, max_pin_name_lengh),
                .name = &.{},
            };

            pin.name = std.fmt.bufPrint(pin.name_buffer, "P{}", .{pin_counter}) catch @panic("not possible");
            pin_counter += 1;

            return pin;
        }

        pub fn deinit(self: *Pin, gpa: std.mem.Allocator) void {
            gpa.free(self.name_buffer);
        }

        pub fn hovered(
            self: Pin,
            circuit_rect: dvui.Rect.Physical,
            mouse_pos: dvui.Point.Physical,
        ) bool {
            const f = dvui.Font{
                .id = .fromName(global.font_name),
                .size = global.circuit_font_size,
            };

            const tolerance = 3;

            const dist_from_point = 10;
            const angle = 15.0 / 180.0 * std.math.pi;

            const start_pos = self.pos.toCircuitPosition(circuit_rect);

            const label_size = dvui.Font.textSize(f, self.name);
            const rect_width = label_size.w + 20;
            const rect_height = label_size.h + 10;

            const trig_height_vert = (comptime std.math.tan(angle)) * rect_width / 2;
            const trig_height_hor = (comptime std.math.tan(angle)) * rect_height / 2;

            const rect = switch (self.rotation) {
                .right => dvui.Rect.Physical{
                    .x = start_pos.x + dist_from_point + trig_height_hor - tolerance,
                    .y = start_pos.y - rect_height / 2 - tolerance,
                    .w = rect_width + tolerance * 2,
                    .h = rect_height + tolerance * 2,
                },
                .left => dvui.Rect.Physical{
                    .x = start_pos.x - (dist_from_point + rect_width + trig_height_hor) - tolerance,
                    .y = start_pos.y - rect_height / 2 - tolerance,
                    .w = rect_width + tolerance * 2,
                    .h = rect_height + tolerance * 2,
                },
                .top => dvui.Rect.Physical{
                    .x = start_pos.x - rect_width / 2 - tolerance,
                    .y = start_pos.y - (rect_height + trig_height_vert + dist_from_point) - tolerance,
                    .w = rect_width + tolerance * 2,
                    .h = rect_height + tolerance * 2,
                },
                .bottom => dvui.Rect.Physical{
                    .x = start_pos.x - rect_width / 2 - tolerance,
                    .y = start_pos.y + trig_height_vert + dist_from_point - tolerance,
                    .w = rect_width + tolerance * 2,
                    .h = rect_height + tolerance * 2,
                },
            };

            return rect.contains(mouse_pos);
        }
    };

    pub fn getAllTerminals(self: *const GraphicCircuit) !std.array_list.Managed(TerminalWithPos) {
        const terminal_count_approx = self.graphic_components.items.len * 2;
        var terminals = try std.array_list.Managed(TerminalWithPos).initCapacity(
            self.allocator,
            terminal_count_approx,
        );

        for (self.graphic_components.items, 0..) |comp, comp_id| {
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
    pub fn traverseWiresForNodes(
        self: *const GraphicCircuit,
        remaining_terminals: *std.array_list.Managed(TerminalWithPos),
        node_terminals: *std.ArrayList(std.ArrayList(NetList.Terminal)),
        node_wires: *std.ArrayList([]usize),
    ) !void {
        // TODO: use wire IDs instead of Wire

        var connected_wire_buffer = try self.allocator.alloc(usize, self.wires.items.len);
        defer self.allocator.free(connected_wire_buffer);

        var remaining_wires = try self.allocator.dupe(Wire, self.wires.items);
        var rem: usize = remaining_wires.len;

        // while there are unconnected wires remaining
        while (rem > 0) {
            //
            var connected_terminals = std.ArrayList(NetList.Terminal){};

            // we choose the wire with the highest ID/index(the last one)
            // so that removing it doesnt change the index of the other wires
            // then we find all the wires that are connected to the chosen wire
            const last_remaining_wire_id = remaining_wires.len - 1;
            const connected_wires = getConnectedWires(
                remaining_wires,
                last_remaining_wire_id,
                connected_wire_buffer[0..],
            );

            // now connected_wires contains all wires that intersect the chosen wire
            // including the chosen wire itself

            // next we find all terminals that are connected to any of the wires
            // we found in the previous step since all these terminals are on the same potential
            for (connected_wires) |wire_idx| {
                const wire = remaining_wires[wire_idx];
                while (getNextConnectedTerminalToWire(wire, remaining_terminals)) |term| {
                    try connected_terminals.append(self.allocator, term);
                }
            }

            try node_terminals.append(self.allocator, connected_terminals);
            const connected_wire_copy = try self.allocator.dupe(usize, connected_wires);
            try node_wires.append(self.allocator, connected_wire_copy);

            // if there are wires remaining copy them into a new buffer
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
        }
    }

    const MergedCircuit = struct {
        nodes: std.ArrayList(NetList.Node),
        wires: std.ArrayList(std.ArrayList(usize)),
    };

    pub fn mergeGroundNodes(
        self: *const GraphicCircuit,
        node_terminals: []std.ArrayList(NetList.Terminal),
        node_wires: [][]usize,
    ) !MergedCircuit {
        // TODO: rewrite this function so that the input parameters
        // are not changed or deallocated
        std.debug.assert(node_terminals.len == node_wires.len);

        const pre_node_count = node_terminals.len;

        var nodes = std.ArrayList(NetList.Node){};
        var wires = std.ArrayList(std.ArrayList(usize)){};

        // add ground node
        try nodes.append(self.allocator, NetList.Node{
            .id = 0,
            .connected_terminals = std.ArrayList(NetList.Terminal){},
            .voltage = null,
        });

        try wires.append(self.allocator, std.ArrayList(usize){});

        for (0..pre_node_count) |pre_node_id| {
            var terminals_for_node = node_terminals[pre_node_id];
            const wires_for_node = node_wires[pre_node_id];

            if (self.nodeHasGround(terminals_for_node.items)) {
                // the terminals are added to the ground node's list of terminals
                // so we can deinit the list containing them
                for (terminals_for_node.items) |term| {
                    const graphic_comp = self.graphic_components.items[term.component_id];
                    graphic_comp.comp.terminal_node_ids[term.terminal_id] = 0;
                    try nodes.items[0].connected_terminals.append(self.allocator, term);
                }
                terminals_for_node.deinit(self.allocator);

                try wires.items[0].appendSlice(self.allocator, wires_for_node);
            } else {
                // if the node doesnt have a GND component connected to it
                // then create its own node
                const node_id = nodes.items.len;
                try nodes.append(self.allocator, NetList.Node{
                    .id = node_id,
                    .connected_terminals = terminals_for_node,
                    .voltage = null,
                });
                for (terminals_for_node.items) |term| {
                    const graphic_comp = self.graphic_components.items[term.component_id];
                    graphic_comp.comp.terminal_node_ids[term.terminal_id] = node_id;
                }

                var wire_buffer = std.ArrayList(usize){};
                try wire_buffer.appendSlice(self.allocator, wires_for_node);
                try wires.append(self.allocator, wire_buffer);
            }
        }

        return MergedCircuit{
            .nodes = nodes,
            .wires = wires,
        };
    }

    fn nodeHasGround(self: *const GraphicCircuit, terminals: []const NetList.Terminal) bool {
        for (terminals) |term| {
            const graphic_comp = self.graphic_components.items[term.component_id];
            const comp_type = @as(bland.Component.DeviceType, graphic_comp.comp.device);
            if (comp_type == bland.Component.DeviceType.ground) {
                return true;
            }
        }

        return false;
    }

    pub fn canPlaceWire(self: *const GraphicCircuit, wire: Wire, exclude_wire_id: ?usize) bool {
        var buffer: [100]component.OccupiedGridPosition = undefined;
        const positions = getOccupiedGridPositions(wire, buffer[0..]);

        for (self.graphic_components.items) |comp| {
            if (comp.intersects(positions)) return false;
        }

        for (self.wires.items, 0..) |other_wire, i| {
            if (exclude_wire_id == i) continue;

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
        self: *const GraphicCircuit,
        comp_type: bland.Component.DeviceType,
        pos: GridPosition,
        rotation: Rotation,
        exclude_comp_id: ?usize,
    ) bool {
        var buffer: [100]component.OccupiedGridPosition = undefined;
        const positions = component.deviceOccupiedGridPositions(
            comp_type,
            pos,
            rotation,
            buffer[0..],
        );
        for (self.graphic_components.items, 0..) |comp, i| {
            if (i == exclude_comp_id) continue;
            if (comp.intersects(positions)) return false;
        }

        var buffer2: [100]component.OccupiedGridPosition = undefined;
        for (self.wires.items) |wire| {
            const wire_positions = getOccupiedGridPositions(wire, buffer2[0..]);
            if (component.occupiedPointsIntersect(positions, wire_positions)) return false;
        }

        return true;
    }

    fn findPinNodes(
        self: *const GraphicCircuit,
        nodes: []const NetList.Node,
        node_wires: []const std.ArrayList(usize),
    ) ![]?usize {
        std.debug.assert(nodes.len == node_wires.len);
        const node_count = nodes.len;
        const pin_to_node_assignments = try self.allocator.alloc(
            ?usize,
            self.pins.items.len,
        );

        for (self.pins.items, 0..) |pin, pin_id| {
            const node_id_found: ?usize = blk: {
                for (0..node_count) |node_id| {
                    const wires = node_wires[node_id].items;
                    for (wires) |wire_id| {
                        const wire = self.wires.items[wire_id];
                        var it = wire.iterator();
                        while (it.next()) |pos| {
                            if (pin.pos.eql(pos)) {
                                break :blk node_id;
                            }
                        }
                    }

                    const terminals = nodes[node_id].connected_terminals.items;
                    for (terminals) |terminal| {
                        // TODO: dont get all the terminals every iteration
                        const comp = self.graphic_components.items[terminal.component_id];
                        var buffer: [16]GridPosition = undefined;
                        const terms_for_comp = comp.terminals(&buffer);
                        const pos = terms_for_comp[terminal.terminal_id];
                        if (pin.pos.eql(pos)) {
                            break :blk node_id;
                        }
                    }
                }
                break :blk null;
            };

            pin_to_node_assignments[pin_id] = node_id_found;
        }

        return pin_to_node_assignments;
    }

    const PinnedNode = struct {
        name: []const u8,
        node_id: usize,
    };

    const SimulationParams = struct {
        netlist: NetList,
        comp_names: []?[]const u8,
        pinned_nodes: []PinnedNode,
    };

    pub fn createSimulationParams(self: *const GraphicCircuit) !SimulationParams {
        var node_terminals = std.ArrayList(
            std.ArrayList(NetList.Terminal),
        ){};
        defer node_terminals.deinit(self.allocator);

        var node_wires = std.ArrayList([]usize){};
        defer {
            for (node_wires.items) |wires| {
                self.allocator.free(wires);
            }
            node_wires.deinit(self.allocator);
        }

        const component_names = try self.copyComponentNames();

        var remaining_terminals = try self.getAllTerminals();
        defer remaining_terminals.deinit();

        // to create the netlist:
        // 1. traverse all the wires
        // 2. find all direct connections (terminal-terminal)
        // 3. merge all the nodes that have a ground connected to them,
        // since they will all have the same potential
        // 4. find the nodes associated with pins

        try self.traverseWiresForNodes(
            &remaining_terminals,
            &node_terminals,
            &node_wires,
        );

        try findAllDirectConnections(
            self.allocator,
            &remaining_terminals,
            &node_terminals,
        );
        const direct_connection_count = node_terminals.items.len - node_wires.items.len;
        for (0..direct_connection_count) |_| {
            try node_wires.append(self.allocator, &.{});
        }

        const merged_circuit = try self.mergeGroundNodes(
            node_terminals.items,
            node_wires.items,
        );

        const nodes = merged_circuit.nodes;
        const wires = merged_circuit.wires;

        const pin_to_node_assignments = try self.findPinNodes(nodes.items, wires.items);

        var pinned_node_count: usize = 0;

        for (pin_to_node_assignments) |node_id_for_pin| {
            if (node_id_for_pin != null) pinned_node_count += 1;
        }

        const pinned_nodes = blk: {
            const pinned_nodes = try self.allocator.alloc(PinnedNode, pinned_node_count);
            var pinned_node_counter: usize = 0;

            for (pin_to_node_assignments, 0..) |node_id_for_pin, pin_idx| {
                const pin = self.pins.items[pin_idx];

                if (node_id_for_pin) |node_id| {
                    pinned_nodes[pinned_node_counter] = PinnedNode{
                        .name = try self.allocator.dupe(u8, pin.name),
                        .node_id = node_id,
                    };
                    pinned_node_counter += 1;
                } else {
                    std.log.warn("Pin '{s}' is not connected to any node", .{pin.name});
                }
            }

            break :blk pinned_nodes;
        };
        var netlist_comps = try std.ArrayList(bland.Component).initCapacity(
            self.allocator,
            self.graphic_components.items.len,
        );

        // TODO: validate values, errors
        for (self.graphic_components.items) |*graphic_comp| {
            switch (graphic_comp.comp.device) {
                .resistor, .capacitor, .inductor => |val| {
                    std.debug.assert(val > 0);
                },
                .ccvs => |*inner| {
                    const comp_id = self.findComponentByName(
                        graphic_comp.value_buffer.ccvs.controller_name_actual,
                    ) orelse @panic("TODO");
                    inner.controller_comp_id = comp_id;
                },
                .cccs => |*inner| {
                    const comp_id = self.findComponentByName(
                        graphic_comp.value_buffer.cccs.controller_name_actual,
                    ) orelse @panic("TODO");
                    inner.controller_comp_id = comp_id;
                },
                else => {},
            }

            try netlist_comps.append(
                self.allocator,
                graphic_comp.comp,
            );
        }

        return SimulationParams{
            .netlist = NetList{
                .nodes = nodes,
                .components = netlist_comps,
            },
            .comp_names = component_names,
            .pinned_nodes = pinned_nodes,
        };
    }

    fn findComponentByName(self: *const GraphicCircuit, name: []const u8) ?usize {
        for (self.graphic_components.items, 0..) |graphic_comp, i| {
            if (std.mem.eql(u8, graphic_comp.comp.name, name)) return i;
        }

        return null;
    }

    fn copyComponentNames(self: *const GraphicCircuit) ![]?[]const u8 {
        const comps = self.graphic_components.items;
        const names = try self.allocator.alloc(?[]const u8, comps.len);
        var idx: usize = 0;
        errdefer {
            for (0..idx) |i| {
                if (names[i]) |name| {
                    self.allocator.free(name);
                }
            }
            self.allocator.free(names);
        }

        while (idx < comps.len) : (idx += 1) {
            const comp = comps[idx];
            if (comp.comp.device == .ground) {
                names[idx] = null;
            } else {
                names[idx] = try self.allocator.dupe(u8, comp.comp.name);
            }
        }

        return names;
    }

    pub fn analyseDC(self: *const GraphicCircuit) void {
        var simulation_params = self.createSimulationParams() catch {
            std.log.err("Failed to build netlist", .{});
            return;
        };
        defer simulation_params.netlist.deinit(self.allocator);

        errdefer {
            for (simulation_params.comp_names) |name| {
                if (name) |str| {
                    self.allocator.free(str);
                }
            }
            self.allocator.free(simulation_params.comp_names);
            for (simulation_params.pinned_nodes) |pinned_node| {
                self.allocator.free(pinned_node.name);
            }
            self.allocator.free(simulation_params.pinned_nodes);
        }

        // TODO
        const result = simulation_params.netlist.analyseDC(self.allocator, null) catch {
            std.log.err("DC analysis failed", .{});
            return;
        };

        const report = AnalysisReport{
            .component_names = simulation_params.comp_names,
            .node_count = simulation_params.netlist.nodes.items.len,
            .pinned_nodes = simulation_params.pinned_nodes,
            .result = .{
                .dc = result,
            },
        };

        analysis_reports.append(self.allocator, report) catch @panic("TODO");
    }

    pub fn analyseTransient(self: *const GraphicCircuit, duration: bland.Float) void {
        var simulation_params = self.createSimulationParams() catch {
            std.log.err("Failed to build netlist", .{});
            return;
        };
        defer simulation_params.netlist.deinit(self.allocator);

        errdefer {
            for (simulation_params.comp_names) |name| {
                if (name) |str| {
                    self.allocator.free(str);
                }
            }
            self.allocator.free(simulation_params.comp_names);
            for (simulation_params.pinned_nodes) |pinned_node| {
                self.allocator.free(pinned_node.name);
            }
            self.allocator.free(simulation_params.pinned_nodes);
        }

        // TODO
        const result = simulation_params.netlist.analyseTransient(
            self.allocator,
            null,
            duration,
        ) catch {
            std.log.err("Transient analysis failed", .{});
            return;
        };

        const report = AnalysisReport{
            .component_names = simulation_params.comp_names,
            .node_count = simulation_params.netlist.nodes.items.len,
            .pinned_nodes = simulation_params.pinned_nodes,
            .result = .{
                .transient = result,
            },
        };

        analysis_reports.append(self.allocator, report) catch @panic("TODO");
    }

    pub fn analyseFrequencySweep(
        self: *const GraphicCircuit,
        start_freq: bland.Float,
        end_freq: bland.Float,
        freq_count: usize,
    ) void {
        // TODO: make these into errors
        std.debug.assert(start_freq >= 0);
        std.debug.assert(end_freq > start_freq);
        std.debug.assert(freq_count > 0);

        var simulation_params = self.createSimulationParams() catch {
            std.log.err("Failed to build netlist", .{});
            return;
        };
        defer simulation_params.netlist.deinit(self.allocator);

        errdefer {
            for (simulation_params.comp_names) |name| {
                if (name) |str| {
                    self.allocator.free(str);
                }
            }
            self.allocator.free(simulation_params.comp_names);
            for (simulation_params.pinned_nodes) |pinned_node| {
                self.allocator.free(pinned_node.name);
            }
            self.allocator.free(simulation_params.pinned_nodes);
        }

        const result = simulation_params.netlist.analyseFrequencySweep(
            self.allocator,
            start_freq,
            end_freq,
            freq_count,
            null,
        ) catch {
            std.log.err("Sinusoidal steady state frequency sweep failed", .{});
            return;
        };

        const report = AnalysisReport{
            .component_names = simulation_params.comp_names,
            .node_count = simulation_params.netlist.nodes.items.len,
            .pinned_nodes = simulation_params.pinned_nodes,
            .result = .{
                .frequency_sweep = result,
            },
        };

        analysis_reports.append(self.allocator, report) catch @panic("TODO");
    }

    pub fn deleteComponent(self: *GraphicCircuit, comp_id: usize) void {
        std.debug.assert(self.graphic_components.items.len > comp_id);

        var comp = self.graphic_components.orderedRemove(comp_id);
        comp.deinit(self.allocator);
    }

    pub fn deleteWire(self: *GraphicCircuit, wire_id: usize) void {
        std.debug.assert(self.wires.items.len > wire_id);
        _ = self.wires.orderedRemove(wire_id);
    }

    pub fn deletePin(self: *GraphicCircuit, pin_id: usize) void {
        std.debug.assert(self.pins.items.len > pin_id);
        var pin = self.pins.orderedRemove(pin_id);
        pin.deinit(self.allocator);
    }
};

pub fn findAllDirectConnections(
    allocator: std.mem.Allocator,
    remaining_terminals: *std.array_list.Managed(TerminalWithPos),
    nodes: *std.ArrayList(std.ArrayList(NetList.Terminal)),
) !void {
    while (remaining_terminals.pop()) |selected_terminal| {
        var connected_terminals = std.ArrayList(NetList.Terminal){};
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
    // we iterate from the back because if the last element
    // is connected then swapRemove doesnt need to copy
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
