const std = @import("std");
const bland = @import("bland.zig");
const matrix = @import("matrix.zig");
const complex_matrix = @import("complex_matrix.zig");
const NetList = @import("NetList.zig");

const Float = bland.Float;
const Complex = bland.Complex;

const MNA = @This();

mat: union(enum) {
    dc: matrix.Matrix(Float),
    ac: complex_matrix.ComplexMatrix(Float),
},
nodes: []const NetList.Node,
component_count: usize,
group_2: []const usize,

pub fn init(
    allocator: std.mem.Allocator,
    nodes: []const NetList.Node,
    group_2: []const usize,
    component_count: usize,
    complex: bool,
) !MNA {
    const total_variable_count = nodes.len - 1 + group_2.len;
    if (complex) {
        return MNA{
            .mat = .{
                .ac = try complex_matrix.ComplexMatrix(Float).init(
                    allocator,
                    total_variable_count,
                    total_variable_count + 1,
                ),
            },
            .nodes = nodes,
            .group_2 = group_2,
            .component_count = component_count,
        };
    } else {
        return MNA{
            .mat = .{
                .dc = try matrix.Matrix(Float).init(
                    allocator,
                    total_variable_count,
                    total_variable_count + 1,
                ),
            },
            .nodes = nodes,
            .group_2 = group_2,
            .component_count = component_count,
        };
    }
}

pub fn zero(self: *MNA) void {
    switch (self.mat) {
        .dc => |mat| {
            for (0..mat.row_count) |row| {
                for (0..mat.col_count) |col| {
                    mat.data[row][col] = 0;
                }
            }
        },
        .ac => |mat| {
            for (0..mat.row_count) |row| {
                for (0..mat.col_count) |col| {
                    mat.data[row][col] = Complex.init(0, 0);
                }
            }
        },
    }
}

pub fn deinit(self: *MNA, allocator: std.mem.Allocator) void {
    switch (self.mat) {
        .dc => |*mat| {
            mat.deinit(allocator);
        },
        .ac => |*mat| {
            mat.deinit(allocator);
        },
    }
}

fn addRealToMatrixCell(
    self: *MNA,
    row: usize,
    col: usize,
    val: Float,
) void {
    switch (self.mat) {
        .dc => |*mat| {
            mat.data[row][col] += val;
        },
        .ac => |*mat| {
            const z = Complex.init(val, 0);
            const prev_val = mat.data[row][col];
            mat.data[row][col] = prev_val.add(z);
        },
    }
}

fn addComplexToMatrixCell(
    self: *MNA,
    row: usize,
    col: usize,
    val: Complex,
) void {
    switch (self.mat) {
        .dc => |_| {
            @panic("trying to add complex to a real MNA");
        },
        .ac => |*mat| {
            const prev_val = mat.data[row][col];
            mat.data[row][col] = prev_val.add(val);
        },
    }
}

pub fn stampVoltageVoltage(
    self: *MNA,
    row_voltage_id: usize,
    col_voltage_id: usize,
    val: Float,
) void {
    // ignore grounds
    if (row_voltage_id == 0 or col_voltage_id == 0) return;
    const row = row_voltage_id - 1;
    const col = col_voltage_id - 1;
    self.addRealToMatrixCell(row, col, val);
}

pub fn stampVoltageCurrent(
    self: *MNA,
    row_voltage_id: usize,
    col_current_id: usize,
    val: Float,
) void {
    // ignore grounds
    if (row_voltage_id == 0) return;

    const row = row_voltage_id - 1;
    const col = self.nodes.len - 1 + col_current_id;
    self.addRealToMatrixCell(row, col, val);
}

pub fn stampCurrentCurrent(
    self: *MNA,
    row_current_id: usize,
    col_current_id: usize,
    val: Float,
) void {
    const row = self.nodes.len - 1 + row_current_id;
    const col = self.nodes.len - 1 + col_current_id;
    self.addRealToMatrixCell(row, col, val);
}

pub fn stampCurrentVoltage(
    self: *MNA,
    row_current_id: usize,
    col_voltage_id: usize,
    val: Float,
) void {
    // ignore ground
    if (col_voltage_id == 0) return;

    const row = self.nodes.len - 1 + row_current_id;
    const col = col_voltage_id - 1;
    self.addRealToMatrixCell(row, col, val);
}

pub fn stampVoltageRHS(
    self: *MNA,
    row_voltage_id: usize,
    val: Float,
) void {
    // ignore ground
    if (row_voltage_id == 0) return;

    const row = row_voltage_id - 1;
    const col = self.nodes.len + self.group_2.len - 1;
    self.addRealToMatrixCell(row, col, val);
}

pub fn stampCurrentRHS(
    self: *MNA,
    row_current_id: usize,
    val: Float,
) void {
    const row = self.nodes.len - 1 + row_current_id;
    const col = self.nodes.len + self.group_2.len - 1;
    self.addRealToMatrixCell(row, col, val);
}

pub fn stampVoltageVoltageComplex(
    self: *MNA,
    row_voltage_id: usize,
    col_voltage_id: usize,
    val: Complex,
) void {
    // ignore grounds
    if (row_voltage_id == 0 or col_voltage_id == 0) return;
    const row = row_voltage_id - 1;
    const col = col_voltage_id - 1;
    self.addComplexToMatrixCell(row, col, val);
}

pub fn stampVoltageCurrentComplex(
    self: *MNA,
    row_voltage_id: usize,
    col_current_id: usize,
    val: Complex,
) void {
    // ignore grounds
    if (row_voltage_id == 0) return;

    const row = row_voltage_id - 1;
    const col = self.nodes.len - 1 + col_current_id;
    self.addComplexToMatrixCell(row, col, val);
}

pub fn stampCurrentCurrentComplex(
    self: *MNA,
    row_current_id: usize,
    col_current_id: usize,
    val: Complex,
) void {
    const row = self.nodes.len - 1 + row_current_id;
    const col = self.nodes.len - 1 + col_current_id;
    self.addComplexToMatrixCell(row, col, val);
}

pub fn stampCurrentVoltageComplex(
    self: *MNA,
    row_current_id: usize,
    col_voltage_id: usize,
    val: Complex,
) void {
    // ignore ground
    if (col_voltage_id == 0) return;

    const row = self.nodes.len - 1 + row_current_id;
    const col = col_voltage_id - 1;
    self.addComplexToMatrixCell(row, col, val);
}

pub fn stampVoltageRHSComplex(
    self: *MNA,
    row_voltage_id: usize,
    val: Complex,
) void {
    // ignore ground
    if (row_voltage_id == 0) return;

    const row = row_voltage_id - 1;
    const col = self.nodes.len + self.group_2.len - 1;
    self.addComplexToMatrixCell(row, col, val);
}

pub fn stampCurrentRHSComplex(
    self: *MNA,
    row_current_id: usize,
    val: Complex,
) void {
    const row = self.nodes.len - 1 + row_current_id;
    const col = self.nodes.len + self.group_2.len - 1;
    self.addComplexToMatrixCell(row, col, val);
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

pub fn solveDC(self: *MNA, allocator: std.mem.Allocator) !DCAnalysisReport {
    var mat = self.mat.dc;

    mat.toRowReducedEchelon();

    var dc_results = try DCAnalysisReport.init(
        allocator,
        self.nodes.len,
        self.component_count,
    );

    dc_results.voltages[0] = 0;
    for (1..self.nodes.len) |i| {
        dc_results.voltages[i] = mat.data[i - 1][mat.col_count - 1];
    }

    // null out currents
    for (0..self.component_count) |i| {
        dc_results.currents[i] = null;
    }

    for (self.group_2, 0..) |current_idx, i| {
        dc_results.currents[current_idx] = mat.data[self.nodes.len + i - 1][mat.col_count - 1];
    }

    return dc_results;
}

pub fn solveAC(self: *MNA, allocator: std.mem.Allocator) !ACAnalysisReport {
    var mat = self.mat.ac;

    mat.toRowReducedEchelon();

    var ac_results = try ACAnalysisReport.init(
        allocator,
        self.nodes.len,
        self.component_count,
    );

    ac_results.voltages[0] = Complex.init(0, 0);
    for (1..self.nodes.len) |i| {
        ac_results.voltages[i] = mat.data[i - 1][mat.col_count - 1];
    }

    // null out currents
    for (0..self.component_count) |i| {
        ac_results.currents[i] = null;
    }

    for (self.group_2, 0..) |current_idx, i| {
        ac_results.currents[current_idx] = mat.data[self.nodes.len + i - 1][mat.col_count - 1];
    }

    return ac_results;
}

pub const DCAnalysisReport = struct {
    voltages: []Float,
    currents: []?Float,

    pub fn init(
        allocator: std.mem.Allocator,
        node_count: usize,
        comp_count: usize,
    ) !DCAnalysisReport {
        return DCAnalysisReport{
            .voltages = try allocator.alloc(
                Float,
                node_count,
            ),
            .currents = try allocator.alloc(
                ?Float,
                comp_count,
            ),
        };
    }

    pub fn deinit(
        self: *DCAnalysisReport,
        allocator: std.mem.Allocator,
    ) void {
        allocator.free(self.voltages);
        allocator.free(self.currents);
        self.* = undefined;
    }

    pub fn dump(self: *DCAnalysisReport) void {
        for (self.voltages, 0..) |v, idx| {
            std.debug.print("v{}: {d}\n", .{ idx, v });
        }

        for (self.currents, 0..) |current, idx| {
            if (current) |c| {
                std.debug.print("i{}: {d}\n", .{ idx, c });
            } else {
                std.debug.print("i{}: ?\n", .{idx});
            }
        }
    }
};

pub const ACAnalysisReport = struct {
    voltages: []Complex,
    currents: []?Complex,

    pub fn init(
        allocator: std.mem.Allocator,
        node_count: usize,
        comp_count: usize,
    ) !ACAnalysisReport {
        return ACAnalysisReport{
            .voltages = try allocator.alloc(
                Complex,
                node_count,
            ),
            .currents = try allocator.alloc(
                ?Complex,
                comp_count,
            ),
        };
    }

    pub fn deinit(
        self: *ACAnalysisReport,
        allocator: std.mem.Allocator,
    ) void {
        allocator.free(self.voltages);
        allocator.free(self.currents);
        self.* = undefined;
    }

    pub fn dump(self: *ACAnalysisReport) void {
        for (self.voltages, 0..) |z, idx| {
            std.debug.print("v{}: ", .{idx});
            complex_matrix.prettyPrintComplex(Float, z);
            std.debug.print("\n", .{});
        }

        for (self.currents, 0..) |current, idx| {
            if (current) |z| {
                std.debug.print("i{}: ", .{idx});
                complex_matrix.prettyPrintComplex(Float, z);
                std.debug.print("\n", .{});
            } else {
                std.debug.print("i{}: ?\n", .{idx});
            }
        }
    }
};
