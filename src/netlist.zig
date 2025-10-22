const std = @import("std");
const circuit = @import("circuit.zig");
const component = @import("component.zig");

const FloatType = circuit.FloatType;
const GraphicCircuit = circuit.GraphicCircuit;
const Component = component.Component;
const MNA = @import("mna.zig").MNA;

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
            .components = std.ArrayList(Component){},
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
        const name_buf = try self.allocator.dupe(u8, name);
        try self.components.append(self.allocator, Component{
            .inner = inner,
            .name_buffer = name_buf,
            .name = name_buf,
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

        for (self.components.items) |*comp| {
            comp.deinit(self.allocator);
        }

        self.nodes.deinit(self.allocator);
        self.components.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn fromCircuit(graphic_circuit: *const GraphicCircuit) !NetList {
        var node_terminals = std.ArrayListUnmanaged(
            std.ArrayListUnmanaged(NetList.Terminal),
        ){};
        defer node_terminals.deinit(graphic_circuit.allocator);

        var remaining_terminals = try graphic_circuit.getAllTerminals();
        defer remaining_terminals.deinit();

        try graphic_circuit.traverseWiresForNodes(
            &remaining_terminals,
            &node_terminals,
        );

        try circuit.findAllDirectConnections(
            graphic_circuit.allocator,
            &remaining_terminals,
            &node_terminals,
        );

        const nodes = try graphic_circuit.mergeGroundNodes(
            node_terminals.items,
        );

        var netlist_comps = try std.ArrayList(Component).initCapacity(
            graphic_circuit.allocator,
            graphic_circuit.graphic_components.items.len,
        );

        for (graphic_circuit.graphic_components.items) |graphic_comp| {
            try netlist_comps.append(
                graphic_circuit.allocator,
                try graphic_comp.comp.clone(graphic_circuit.allocator),
            );
        }

        return NetList{
            .allocator = graphic_circuit.allocator,
            .nodes = nodes,
            .components = netlist_comps,
        };
    }

    // TODO: instead of group 2 pass the components whose
    // currents are included in group 2
    // since we will add currents used by CCVS, etc later too
    // so the name group_2 is misleading
    fn createMNAMatrix(self: *NetList, group_2: []const usize) !MNA {
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

    pub fn analyse(self: *NetList, currents_watched: []const usize) !AnalysationResult {
        // group edges:
        // - group 1(i1): all elements whose current will be eliminated
        // - group 2(i2): all other elements

        // since we include all nodes, theres no need to explicitly store their order
        // however we store i2 elements

        var group_2 = std.ArrayListUnmanaged(usize){};
        try group_2.appendSlice(self.allocator, currents_watched);
        defer group_2.deinit(self.allocator);

        // TODO: include currents that are control variables
        for (0.., self.components.items) |idx, *comp| {
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
                .ccvs => |*inner| {
                    const controller_comp_idx = self.findComponentByName(
                        inner.controller_name,
                    ) orelse @panic("TODO");

                    inner.controller_group_2_idx = group_2.items.len;

                    // controller's current
                    group_2.append(self.allocator, controller_comp_idx) catch {
                        @panic("Failed to build netlist");
                    };

                    // ccvs's current
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

    pub fn findComponentByName(self: *const NetList, name: []const u8) ?usize {
        for (self.components.items, 0..) |comp, i| {
            if (std.mem.eql(u8, comp.name, name)) return i;
        }

        return null;
    }
};
