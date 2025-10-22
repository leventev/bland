const std = @import("std");
const matrix = @import("matrix.zig");
const circuit = @import("circuit.zig");

const NetList = @import("netlist.zig").NetList;
const FloatType = circuit.FloatType;

pub const MNA = struct {
    mat: matrix.Matrix(FloatType),
    nodes: []const NetList.Node,
    group_2: []const usize,

    pub fn init(
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
