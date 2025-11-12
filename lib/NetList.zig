const std = @import("std");
const bland = @import("bland.zig");
const component = @import("component.zig");
const MNA = @import("MNA.zig");

const Float = bland.Float;
const Complex = bland.Complex;
const Component = component.Component;

// TODO: use u32 instead of usize for IDs?

nodes: std.ArrayListUnmanaged(Node),
components: std.ArrayListUnmanaged(Component),

pub const ground_node_id = 0;
pub const DCAnalysisReport = MNA.DCAnalysisReport;
pub const ACAnalysisReport = MNA.ACAnalysisReport;

const NetList = @This();

pub const Terminal = struct {
    component_id: usize,
    terminal_id: usize,
};

pub const Node = struct {
    id: usize,
    connected_terminals: std.ArrayListUnmanaged(Terminal),
    voltage: ?Float,
};

pub fn init(allocator: std.mem.Allocator) !NetList {
    var nodes = std.ArrayListUnmanaged(Node){};
    try nodes.append(allocator, .{
        .id = ground_node_id,
        .connected_terminals = std.ArrayListUnmanaged(Terminal){},
        .voltage = 0,
    });

    return NetList{
        .nodes = nodes,
        .components = std.ArrayList(Component){},
    };
}

pub fn allocateNode(self: *NetList, allocator: std.mem.Allocator) !usize {
    const next_id = self.nodes.items.len;
    try self.nodes.append(allocator, .{
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
    allocator: std.mem.Allocator,
    device: Component.Device,
    name: []const u8,
    node_ids: []const usize,
) !usize {
    const id = self.components.items.len;
    try self.components.append(allocator, Component{
        .device = device,
        .name = name,
        .terminal_node_ids = try allocator.dupe(usize, node_ids),
    });
    for (node_ids, 0..) |node_id, term_id| {
        try self.addComponentConnection(allocator, node_id, id, term_id);
    }
    return id;
}

pub fn addComponentConnection(
    self: *NetList,
    allocator: std.mem.Allocator,
    node_id: usize,
    comp_id: usize,
    term_id: usize,
) !void {
    // TODO: error instead of assert
    std.debug.assert(node_id < self.nodes.items.len);
    std.debug.assert(comp_id < self.components.items.len);

    try self.nodes.items[node_id].connected_terminals.append(
        allocator,
        NetList.Terminal{
            .component_id = comp_id,
            .terminal_id = term_id,
        },
    );
}

pub fn deinit(self: *NetList, allocator: std.mem.Allocator) void {
    for (self.nodes.items) |*node| {
        node.connected_terminals.deinit(allocator);
    }

    self.nodes.deinit(allocator);
    self.components.deinit(allocator);
    self.* = undefined;
}

fn createMNAMatrix(
    self: *NetList,
    allocator: std.mem.Allocator,
    group_2: []const usize,
    angular_frequency: Float,
    ac_analysis: bool,
) !MNA {
    // create matrix (|v| + |i2| X |v| + |i2| + 1)
    // where v is all nodes except ground
    // the last column is the RHS of the equation Ax=b
    // basically (A|b) where b is an (|v| + |i2| X 1) matrix

    if (!ac_analysis) {
        std.debug.assert(angular_frequency == 0);
    }

    var mna = try MNA.init(
        allocator,
        self.nodes.items,
        group_2,
        self.components.items.len,
        ac_analysis,
    );

    mna.zero();

    for (0.., self.components.items) |idx, comp| {
        const current_group_2_idx = std.mem.indexOf(usize, group_2, &.{idx});
        comp.device.stampMatrix(
            comp.terminal_node_ids,
            &mna,
            current_group_2_idx,
            angular_frequency,
        );
    }

    return mna;
}

const Group2 = struct {
    arr: std.ArrayList(usize),

    fn addComponents(
        self: *Group2,
        allocator: std.mem.Allocator,
        comp_indices: []const usize,
    ) !void {
        for (comp_indices) |comp_idx| {
            _ = try self.addComponent(allocator, comp_idx);
        }
    }

    fn addComponent(
        self: *Group2,
        allocator: std.mem.Allocator,
        comp_idx: usize,
    ) !usize {
        const idx = std.mem.indexOf(usize, self.arr.items, &.{comp_idx});
        if (idx) |i| {
            return i;
        }

        const group_2_id = self.arr.items.len;
        try self.arr.append(allocator, comp_idx);

        return group_2_id;
    }

    fn init() Group2 {
        return Group2{ .arr = std.ArrayList(usize){} };
    }

    fn deinit(self: *Group2, allocator: std.mem.Allocator) void {
        self.arr.deinit(allocator);
    }
};

fn createGroup2(
    self: *NetList,
    allocator: std.mem.Allocator,
    currents_watched: ?[]const usize,
) !Group2 {
    // group edges:
    // - group 1(i1): all elements whose current will be eliminated
    // - group 2(i2): all other elements

    var group_2 = Group2.init();

    if (currents_watched) |currs| {
        try group_2.addComponents(allocator, currs);

        for (0.., self.components.items) |idx, *comp| {
            switch (comp.device) {
                .voltage_source, .inductor => {
                    _ = try group_2.addComponent(allocator, idx);
                },
                .ccvs => |*inner| {
                    //const controller_comp_idx = self.findComponentByName(
                    //    inner.controller_name,
                    //) orelse @panic("TODO");

                    // controller's current
                    inner.controller_comp_id = try group_2.addComponent(
                        allocator,
                        inner.controller_comp_id,
                    );

                    // ccvs's current
                    _ = try group_2.addComponent(allocator, idx);
                },
                .cccs => |*inner| {
                    //const controller_comp_idx = self.findComponentByName(
                    //    inner.controller_name,
                    //) orelse @panic("TODO");

                    // controller's current
                    inner.controller_comp_id = try group_2.addComponent(
                        allocator,
                        inner.controller_comp_id,
                    );

                    // ccvs's current
                    _ = try group_2.addComponent(allocator, idx);
                },
                else => {},
            }
        }
    } else {
        for (0..self.components.items.len) |i| {
            // TODO: optimize
            _ = try group_2.addComponent(allocator, i);
        }
    }

    return group_2;
}

pub fn analyseDC(
    self: *NetList,
    allocator: std.mem.Allocator,
    currents_watched: ?[]const usize,
) !MNA.DCAnalysisReport {
    var group_2 = try self.createGroup2(allocator, currents_watched);
    defer group_2.deinit(allocator);

    // create matrix (|v| + |i2| X |v| + |i2| + 1)
    // iterate over all elements and stamp them onto the matrix
    var mna = self.createMNAMatrix(allocator, group_2.arr.items, 0, false) catch {
        @panic("Failed to build netlist");
    };
    defer mna.deinit(allocator);

    // solve the matrix with Gauss elimination
    const res = try mna.solveDC(allocator);
    return res;
}

pub fn analyseAC(
    self: *NetList,
    allocator: std.mem.Allocator,
    currents_watched: ?[]const usize,
    frequency: Float,
) !MNA.ACAnalysisReport {
    std.debug.assert(frequency >= 0);
    const angular_frequency = 2 * std.math.pi * frequency;

    var group_2 = try self.createGroup2(allocator, currents_watched);
    defer group_2.deinit(allocator);

    // create matrix (|v| + |i2| X |v| + |i2| + 1)
    // iterate over all elements and stamp them onto the matrix
    var mna = self.createMNAMatrix(allocator, group_2.arr.items, angular_frequency, true) catch {
        @panic("Failed to build netlist");
    };
    defer mna.deinit(allocator);

    // solve the matrix with Gauss elimination
    const res = try mna.solveAC(allocator);
    return res;
}

pub const FrequencySweepReport = struct {
    /// frequency values
    frequency_values: []Float,

    /// all voltage values for every frequency are allocated together
    all_voltages: []Complex,

    /// all currents values for every frequency are allocated at the same time
    all_currents: []?Complex,

    fn init(
        allocator: std.mem.Allocator,
        node_count: usize,
        component_count: usize,
        start_freq: Float,
        end_freq: Float,
        frequency_count: usize,
    ) !FrequencySweepReport {
        // TODO: errors instead of assert
        std.debug.assert(frequency_count > 0);
        std.debug.assert(start_freq > 0);
        std.debug.assert(end_freq > start_freq);

        std.debug.assert(node_count > 0);
        std.debug.assert(component_count > 0);

        const all_voltages = try allocator.alloc(
            Complex,
            node_count * frequency_count,
        );
        errdefer allocator.free(all_voltages);

        const all_currents = try allocator.alloc(
            ?Complex,
            component_count * frequency_count,
        );
        errdefer allocator.free(all_currents);

        const frequency_values = try allocator.alloc(Float, frequency_count);

        // TODO: allow 0Hz
        const start_freq_exponent: Float = std.math.log10(start_freq);
        const end_freq_exponent: Float = std.math.log10(end_freq);
        const step: Float = (end_freq_exponent - start_freq_exponent) / @as(Float, @floatFromInt(frequency_count));
        for (0..frequency_count) |i| {
            const exp_off = @as(Float, @floatFromInt(i)) * step;
            const exponent: Float = start_freq_exponent + exp_off;
            const frequency: Float = std.math.pow(Float, 10, exponent);
            frequency_values[i] = frequency;
        }

        return FrequencySweepReport{
            .all_voltages = all_voltages,
            .all_currents = all_currents,
            .frequency_values = frequency_values,
        };
    }

    pub fn deinit(self: *FrequencySweepReport, allocator: std.mem.Allocator) void {
        allocator.free(self.frequency_values);
        allocator.free(self.all_voltages);
        allocator.free(self.all_currents);
        self.* = undefined;
    }

    pub fn nodeCount(self: *const FrequencySweepReport) usize {
        // TODO
        return @divExact(self.all_voltages.len, self.frequency_values.len);
    }

    pub fn componentCount(self: *const FrequencySweepReport) usize {
        // TODO
        return @divExact(self.all_currents.len, self.frequency_values.len);
    }

    pub fn voltage(self: *const FrequencySweepReport, node_idx: usize) []const Complex {
        const voltage_count = self.nodeCount();
        std.debug.assert(node_idx < voltage_count);
        const start_idx = node_idx * self.frequency_values.len;
        const end_idx = (node_idx + 1) * self.frequency_values.len;
        return self.all_voltages[start_idx..end_idx];
    }

    pub fn current(self: *const FrequencySweepReport, comp_idx: usize) []const ?Complex {
        const component_count = self.componentCount();
        std.debug.assert(comp_idx < component_count);
        const start_idx = comp_idx * self.frequency_values.len;
        const end_idx = (comp_idx + 1) * self.frequency_values.len;
        return self.all_currents[start_idx..end_idx];
    }

    pub fn analysisReportForFreq(
        self: *const FrequencySweepReport,
        freq_idx: usize,
        report_buff: *ACAnalysisReport,
    ) void {
        std.debug.assert(freq_idx < self.frequency_values.len);
        for (0..report_buff.voltages.len) |idx| {
            report_buff.voltages[idx] = self.voltage(idx)[freq_idx];
        }

        for (0..report_buff.currents.len) |idx| {
            report_buff.currents[idx] = self.current(idx)[freq_idx];
        }
    }
};

pub fn analyseFrequencySweep(
    self: *NetList,
    allocator: std.mem.Allocator,
    start_freq: Float,
    end_freq: Float,
    freq_count: usize,
    currents_watched: ?[]const usize,
) !FrequencySweepReport {

    // TODO: make these into errors
    std.debug.assert(start_freq >= 0);
    std.debug.assert(end_freq > start_freq);
    std.debug.assert(freq_count > 0);

    var fw_report = try FrequencySweepReport.init(
        allocator,
        self.nodes.items.len,
        self.components.items.len,
        start_freq,
        end_freq,
        freq_count,
    );

    // TODO:
    for (fw_report.frequency_values, 0..) |freq, freq_idx| {
        // TODO
        var report = try self.analyseAC(allocator, currents_watched, freq);
        defer report.deinit(allocator);

        for (0..self.nodes.items.len) |node_idx| {
            const idx = node_idx * freq_count + freq_idx;
            fw_report.all_voltages[idx] = report.voltages[node_idx];
        }

        for (0..self.components.items.len) |comp_idx| {
            const idx = comp_idx * freq_count + freq_idx;
            fw_report.all_currents[idx] = report.currents[comp_idx];
        }
    }

    return fw_report;
}

pub fn findComponentByName(self: *const NetList, name: []const u8) ?usize {
    for (self.components.items, 0..) |comp, i| {
        if (std.mem.eql(u8, comp.name, name)) return i;
    }

    return null;
}
