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
pub const DCAnalysisReport = MNA.RealAnalysisReport;
pub const ACAnalysisReport = MNA.ComplexAnalysisReport;

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

pub const Error = error{
    InvalidComponentID,
    InvalidNodeID,
    InvalidFrequency,
    InvalidFrequencyRange,
} || std.mem.Allocator.Error;

pub fn init(allocator: std.mem.Allocator) Error!NetList {
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

pub fn allocateNode(self: *NetList, allocator: std.mem.Allocator) Error!usize {
    const next_id = self.nodes.items.len;
    try self.nodes.append(allocator, .{
        .id = next_id,
        .connected_terminals = std.ArrayListUnmanaged(Terminal){},
        .voltage = null,
    });

    return next_id;
}

pub fn addComponent(
    self: *NetList,
    allocator: std.mem.Allocator,
    device: Component.Device,
    name: []const u8,
    node_ids: []const usize,
) Error!usize {
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
) Error!void {
    if (node_id >= self.nodes.items.len) return error.InvalidNodeID;
    if (comp_id >= self.components.items.len) return error.InvalidComponentID;

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

// TODO: get rid of angular_frequency and ac_analysis
fn createMNAMatrix(
    self: *NetList,
    allocator: std.mem.Allocator,
    group_2: []const usize,
    angular_frequency: Float,
    ac_analysis: bool,
) Error!MNA {
    // create matrix (|v| + |i2| X |v| + |i2| + 1)
    // where v is all nodes except ground
    // the last column is the RHS of the equation Ax=b
    // basically (A|b) where b is an (|v| + |i2| X 1) matrix

    if (ac_analysis and angular_frequency <= 0) {
        return error.InvalidFrequency;
    }

    var mna = MNA.init(
        allocator,
        self.nodes.items,
        group_2,
        self.components.items.len,
        ac_analysis,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |e| {
            @panic(@errorName(e));
        },
    };

    mna.zero();

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
                    // controller's current
                    inner.controller_comp_id = try group_2.addComponent(
                        allocator,
                        inner.controller_comp_id,
                    );

                    // ccvs's current
                    _ = try group_2.addComponent(allocator, idx);
                },
                .cccs => |*inner| {
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
) Error!MNA.RealAnalysisReport {
    const start_time: i64 = std.time.microTimestamp();

    var group_2 = try self.createGroup2(allocator, currents_watched);
    defer group_2.deinit(allocator);

    // create matrix (|v| + |i2| X |v| + |i2| + 1)
    // iterate over all elements and stamp them onto the matrix
    var mna = try self.createMNAMatrix(allocator, group_2.arr.items, 0, false);
    defer mna.deinit(allocator);

    for (0.., self.components.items) |idx, comp| {
        const current_group_2_idx = std.mem.indexOf(usize, group_2.arr.items, &.{idx});
        comp.device.stampMatrix(
            comp.terminal_node_ids,
            &mna,
            current_group_2_idx,
            .dc,
        );
    }

    // solve the matrix with Gauss elimination
    const res = try mna.solveReal(allocator);

    const end_time: i64 = std.time.microTimestamp();
    const elapsed_us: f64 = @as(f64, @floatFromInt(end_time - start_time));
    const elapsed_s = elapsed_us / 1e6;

    var time_buff: [32]u8 = undefined;
    const time_str = bland.units.formatUnitBuf(
        &time_buff,
        .time,
        elapsed_s,
        3,
    ) catch unreachable;

    bland.log.info("DC analysis took {s}", .{time_str});

    return res;
}

pub fn analyseTransient(
    self: *NetList,
    allocator: std.mem.Allocator,
    currents_watched: ?[]const usize,
) TransientReport.Error!TransientReport {
    const start_time: i64 = std.time.microTimestamp();

    var group_2 = try self.createGroup2(allocator, currents_watched);
    defer group_2.deinit(allocator);

    const time_step: Float = 1e-5;
    const until: Float = 0.01;

    const time_point_count: usize = @as(usize, @intFromFloat(until / time_step)) + 1;

    // TODO: adaptive time steps
    var transient_report = try TransientReport.init(
        allocator,
        self.nodes.items.len,
        self.components.items.len,
        time_point_count,
    );

    // create matrix (|v| + |i2| X |v| + |i2| + 1)
    // iterate over all elements and stamp them onto the matrix
    // get values at t=0
    //var dc_res = try self.analyseDC(allocator, currents_watched);

    for (0..self.nodes.items.len) |node_idx| {
        const idx = node_idx * time_point_count;
        transient_report.all_voltages[idx] = 0;
        //transient_report.all_voltages[idx] = dc_res.voltages[node_idx];
        //std.debug.print("dc_res: {} = {}", .{ node_idx, dc_res.voltages[node_idx] });
    }

    for (0..self.components.items.len) |comp_idx| {
        const idx = comp_idx * time_point_count;
        //transient_report.all_currents[idx] = dc_res.currents[comp_idx];
        transient_report.all_currents[idx] = 0;
    }

    //dc_res.deinit(allocator);

    // t0 = 0
    transient_report.time_values[0] = 0;
    var mna = try self.createMNAMatrix(allocator, group_2.arr.items, 0, false);
    defer mna.deinit(allocator);

    for (1..time_point_count) |time_idx| {
        const time = @as(Float, @floatFromInt(time_idx)) * time_step;
        //std.debug.print("{}/{}: {}\n", .{ time_idx, time_point_count, time });
        transient_report.time_values[time_idx] = time;

        mna.zero();

        for (0.., self.components.items) |comp_id, comp| {
            const current_group_2_idx = std.mem.indexOf(usize, group_2.arr.items, &.{comp_id});
            // TODO:
            if (comp.device == .ground) {
                comp.device.stampMatrix(comp.terminal_node_ids, &mna, current_group_2_idx, .{
                    .transient = .{
                        .time_step = time_step,
                        .prev_voltage = 0,
                        .prev_current = 0,
                    },
                });
            } else {
                const voltage_pos = (try transient_report.voltage(comp.terminal_node_ids[0]))[time_idx - 1];
                const voltage_neg = (try transient_report.voltage(comp.terminal_node_ids[1]))[time_idx - 1];
                const voltage_prev = voltage_pos - voltage_neg;
                const current_prev = (try transient_report.current(comp_id))[time_idx - 1];

                comp.device.stampMatrix(comp.terminal_node_ids, &mna, current_group_2_idx, .{
                    .transient = .{
                        .time_step = time_step,
                        .prev_voltage = voltage_prev,
                        .prev_current = current_prev,
                    },
                });
            }
        }

        // TODO: no allocation
        var step_res = try mna.solveReal(allocator);
        defer step_res.deinit(allocator);

        for (0..self.nodes.items.len) |node_idx| {
            const idx = node_idx * time_point_count + time_idx;
            transient_report.all_voltages[idx] = step_res.voltages[node_idx];
        }

        for (0.., self.components.items) |comp_idx, comp| {
            const idx = comp_idx * time_point_count + time_idx;

            const current_now = switch (comp.device) {
                .capacitor => |c| blk: {
                    const node_plus_id = comp.terminal_node_ids[0];
                    const node_minus_id = comp.terminal_node_ids[1];
                    const voltages_plus = transient_report.voltage(node_plus_id) catch unreachable;
                    const voltages_minus = transient_report.voltage(node_minus_id) catch unreachable;
                    const currents = transient_report.current(comp_idx) catch unreachable;
                    const voltage_now = voltages_plus[time_idx] - voltages_minus[time_idx];
                    const voltage_prev = voltages_plus[time_idx - 1] - voltages_minus[time_idx - 1];
                    const current_prev = currents[time_idx - 1].?;
                    break :blk (2 * c) / time_step * (voltage_now - voltage_prev) - current_prev;
                },
                .inductor => |l| blk: {
                    const node_plus_id = comp.terminal_node_ids[0];
                    const node_minus_id = comp.terminal_node_ids[1];
                    const voltages_plus = transient_report.voltage(node_plus_id) catch unreachable;
                    const voltages_minus = transient_report.voltage(node_minus_id) catch unreachable;
                    const currents = transient_report.current(comp_idx) catch unreachable;
                    const voltage_now = voltages_plus[time_idx] - voltages_minus[time_idx];
                    const voltage_prev = voltages_plus[time_idx - 1] - voltages_minus[time_idx - 1];
                    const current_prev = currents[time_idx - 1].?;
                    break :blk time_step / (2 * l) * (voltage_now + voltage_prev) + current_prev;
                },
                else => step_res.currents[comp_idx],
            };

            transient_report.all_currents[idx] = current_now;
        }
    }

    const end_time: i64 = std.time.microTimestamp();
    const elapsed_us: f64 = @as(f64, @floatFromInt(end_time - start_time));
    const elapsed_s = elapsed_us / 1e6;

    var time_buff: [32]u8 = undefined;
    const time_str = bland.units.formatUnitBuf(
        &time_buff,
        .time,
        elapsed_s,
        3,
    ) catch unreachable;

    bland.log.info("Transient analysis took {s}", .{time_str});

    return transient_report;
}

pub fn analyseSinusoidalSteadyState(
    self: *NetList,
    allocator: std.mem.Allocator,
    currents_watched: ?[]const usize,
    frequency: Float,
) Error!MNA.ComplexAnalysisReport {
    std.debug.assert(frequency >= 0);
    const angular_frequency = 2 * std.math.pi * frequency;

    var group_2 = try self.createGroup2(allocator, currents_watched);
    defer group_2.deinit(allocator);

    // create matrix (|v| + |i2| X |v| + |i2| + 1)
    // iterate over all elements and stamp them onto the matrix
    var mna = try self.createMNAMatrix(allocator, group_2.arr.items, angular_frequency, true);
    defer mna.deinit(allocator);

    for (0.., self.components.items) |idx, comp| {
        const current_group_2_idx = std.mem.indexOf(usize, group_2.arr.items, &.{idx});
        comp.device.stampMatrix(
            comp.terminal_node_ids,
            &mna,
            current_group_2_idx,
            .{
                .sin_steady_state = angular_frequency,
            },
        );
    }

    // solve the matrix with Gauss elimination
    const res = try mna.solveComplex(allocator);
    return res;
}

pub const FrequencySweepReport = struct {
    /// frequency values
    frequency_values: []Float,

    node_count: usize,
    component_count: usize,

    /// all voltage values for every frequency are allocated together
    all_voltages: []Complex,

    /// all currents values for every frequency are allocated at the same time
    all_currents: []?Complex,

    pub const Error = error{
        InvalidFequencyIdx,
    } || NetList.Error;

    fn init(
        allocator: std.mem.Allocator,
        node_count: usize,
        component_count: usize,
        start_freq: Float,
        end_freq: Float,
        frequency_count: usize,
    ) FrequencySweepReport.Error!FrequencySweepReport {
        if (frequency_count < 2) return error.InvalidFrequencyRange;
        if (start_freq <= 0) return error.InvalidFrequencyRange;
        if (start_freq >= end_freq) return error.InvalidFrequencyRange;

        // TODO: figure out whats the best way to go about handling this error
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

        const start_freq_exponent: Float = std.math.log10(start_freq);
        const end_freq_exponent: Float = std.math.log10(end_freq);
        const f_exp_diff = end_freq_exponent - start_freq_exponent;
        const step: Float = f_exp_diff / @as(Float, @floatFromInt(frequency_count));
        for (0..frequency_count) |i| {
            const exp_off = @as(Float, @floatFromInt(i)) * step;
            const exponent: Float = start_freq_exponent + exp_off;
            const frequency: Float = std.math.pow(Float, 10, exponent);
            frequency_values[i] = frequency;
        }

        return FrequencySweepReport{
            .all_voltages = all_voltages,
            .all_currents = all_currents,
            .node_count = node_count,
            .component_count = component_count,
            .frequency_values = frequency_values,
        };
    }

    pub fn deinit(self: *FrequencySweepReport, allocator: std.mem.Allocator) void {
        allocator.free(self.frequency_values);
        allocator.free(self.all_voltages);
        allocator.free(self.all_currents);
        self.* = undefined;
    }

    pub fn voltage(
        self: *const FrequencySweepReport,
        node_idx: usize,
    ) FrequencySweepReport.Error![]const Complex {
        if (node_idx >= self.node_count) return error.InvalidNodeID;
        const start_idx = node_idx * self.frequency_values.len;
        const end_idx = (node_idx + 1) * self.frequency_values.len;
        return self.all_voltages[start_idx..end_idx];
    }

    pub fn current(
        self: *const FrequencySweepReport,
        comp_idx: usize,
    ) FrequencySweepReport.Error![]const ?Complex {
        if (comp_idx >= self.component_count) return error.InvalidComponentID;
        const start_idx = comp_idx * self.frequency_values.len;
        const end_idx = (comp_idx + 1) * self.frequency_values.len;
        return self.all_currents[start_idx..end_idx];
    }

    pub fn analysisReportForFreq(
        self: *const FrequencySweepReport,
        freq_idx: usize,
        report_buff: *ACAnalysisReport,
    ) FrequencySweepReport.Error!void {
        if (freq_idx >= self.frequency_values.len) return error.InvalidFequencyIdx;
        for (0..report_buff.voltages.len) |idx| {
            const voltage_for_freqs = self.voltage(idx) catch unreachable;
            report_buff.voltages[idx] = voltage_for_freqs[freq_idx];
        }

        for (0..report_buff.currents.len) |idx| {
            const current_for_freqs = self.current(idx) catch unreachable;
            report_buff.currents[idx] = current_for_freqs[freq_idx];
        }
    }
};

pub const TransientReport = struct {
    /// time values
    time_values: []Float,

    node_count: usize,
    component_count: usize,

    /// all voltage values for every time point are allocated together
    all_voltages: []Float,

    /// all currents values for every time point are allocated at the same time
    all_currents: []?Float,

    pub const Error = error{
        InvalidTimeIdx,
    } || NetList.Error;

    fn init(
        allocator: std.mem.Allocator,
        node_count: usize,
        component_count: usize,
        time_count: usize,
    ) TransientReport.Error!TransientReport {
        if (time_count < 1) return error.InvalidFrequencyRange;

        // TODO: figure out whats the best way to go about handling this error
        std.debug.assert(node_count > 0);
        std.debug.assert(component_count > 0);

        const all_voltages = try allocator.alloc(
            Float,
            node_count * time_count,
        );
        errdefer allocator.free(all_voltages);

        const all_currents = try allocator.alloc(
            ?Float,
            component_count * time_count,
        );
        errdefer allocator.free(all_currents);

        const time_values = try allocator.alloc(Float, time_count);

        return TransientReport{
            .all_voltages = all_voltages,
            .all_currents = all_currents,
            .node_count = node_count,
            .component_count = component_count,
            .time_values = time_values,
        };
    }

    pub fn deinit(self: *TransientReport, allocator: std.mem.Allocator) void {
        allocator.free(self.time_values);
        allocator.free(self.all_voltages);
        allocator.free(self.all_currents);
        self.* = undefined;
    }

    pub fn voltage(
        self: *const TransientReport,
        node_idx: usize,
    ) TransientReport.Error![]const Float {
        if (node_idx >= self.node_count) return error.InvalidNodeID;
        const start_idx = node_idx * self.time_values.len;
        const end_idx = (node_idx + 1) * self.time_values.len;
        return self.all_voltages[start_idx..end_idx];
    }

    pub fn current(
        self: *const TransientReport,
        comp_idx: usize,
    ) TransientReport.Error![]const ?Float {
        if (comp_idx >= self.component_count) return error.InvalidComponentID;
        const start_idx = comp_idx * self.time_values.len;
        const end_idx = (comp_idx + 1) * self.time_values.len;
        return self.all_currents[start_idx..end_idx];
    }

    //pub fn analysisReportForTime(
    //    self: *const TransientReport,
    //    freq_idx: usize,
    //    report_buff: *ACAnalysisReport,
    //) FrequencySweepReport.Error!void {
    //    if (freq_idx >= self.frequency_values.len) return error.InvalidFequencyIdx;
    //    for (0..report_buff.voltages.len) |idx| {
    //        const voltage_for_freqs = self.voltage(idx) catch unreachable;
    //        report_buff.voltages[idx] = voltage_for_freqs[freq_idx];
    //    }
    //
    //    for (0..report_buff.currents.len) |idx| {
    //        const current_for_freqs = self.current(idx) catch unreachable;
    //        report_buff.currents[idx] = current_for_freqs[freq_idx];
    //    }
    //}
};

pub fn analyseFrequencySweep(
    self: *NetList,
    allocator: std.mem.Allocator,
    start_freq: Float,
    end_freq: Float,
    freq_count: usize,
    currents_watched: ?[]const usize,
) FrequencySweepReport.Error!FrequencySweepReport {
    const start_time: i64 = std.time.microTimestamp();

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
        var report = try self.analyseSinusoidalSteadyState(allocator, currents_watched, freq);
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

    const end_time: i64 = std.time.microTimestamp();
    const elapsed_us: f64 = @as(f64, @floatFromInt(end_time - start_time));
    const elapsed_s = elapsed_us / 1e6;

    var time_buff: [32]u8 = undefined;
    const time_str = bland.units.formatUnitBuf(
        &time_buff,
        .time,
        elapsed_s,
        3,
    ) catch unreachable;

    var freq1_buff: [32]u8 = undefined;
    const freq1_str = bland.units.formatUnitBuf(
        &freq1_buff,
        .frequency,
        start_freq,
        1,
    ) catch unreachable;
    var freq2_buff: [32]u8 = undefined;
    const freq2_str = bland.units.formatUnitBuf(
        &freq2_buff,
        .frequency,
        end_freq,
        1,
    ) catch unreachable;

    bland.log.info("Sinusoidal steady-state frequency sweep({s}-{s}, {} points) took {s}", .{
        freq1_str,
        freq2_str,
        freq_count,
        time_str,
    });

    return fw_report;
}
