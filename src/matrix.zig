const std = @import("std");

pub fn Matrix(comptime T: type) type {
    return struct {
        row_count: usize,
        col_count: usize,
        // first index is row, second index is column
        data: [][]T,

        pub fn init(
            allocator: std.mem.Allocator,
            row_count: usize,
            col_count: usize,
        ) !Matrix(T) {
            var data: [][]T = try allocator.alloc([]T, row_count);
            // maybe do a single allocation for all rows and then just slice them?
            for (0..row_count) |i| {
                data[i] = try allocator.alloc(T, col_count);
            }

            return Matrix(T){
                .col_count = col_count,
                .row_count = row_count,
                .data = data,
            };
        }

        pub fn deinit(self: *Matrix(T), allocator: std.mem.Allocator) void {
            for (0..self.row_count) |i| {
                allocator.free(self.data[i]);
                self.data[i] = undefined;
            }

            allocator.free(self.data);
            self.data = undefined;
            self.row_count = 0;
            self.col_count = 0;
        }

        pub fn dump(self: Matrix(T)) void {
            for (0..self.row_count) |row| {
                for (0..self.col_count) |col| {
                    std.debug.print("{} ", .{self.data[row][col]});
                }
                std.debug.print("\n", .{});
            }
        }

        pub fn swapRows(self: *Matrix(T), row1: usize, row2: usize) void {
            std.debug.assert(row1 < self.row_count);
            std.debug.assert(row2 < self.row_count);
            const temp = self.data[row1];
            self.data[row1] = self.data[row2];
            self.data[row2] = temp;
        }

        pub fn scaleRow(self: *Matrix(T), row: usize, scale: T) void {
            std.debug.assert(row < self.row_count);
            for (0..self.col_count) |col| {
                self.data[row][col] *= scale;
            }
        }

        // row2 = row2 + scale * row1
        pub fn addRows(self: *Matrix(T), row1: usize, row2: usize, scale: T) void {
            std.debug.assert(row1 < self.row_count);
            std.debug.assert(row2 < self.row_count);
            for (0..self.col_count) |col| {
                self.data[row2][col] += self.data[row1][col] * scale;
            }
        }

        pub fn gaussJordanElimination(self: *Matrix(T)) void {
            var row: usize = 0;
            var col: usize = 0;

            while (row < self.row_count and col < self.col_count) : (col += 1) {
                // find the first non empty row and use that as the pivot
                var pivot_row: ?usize = null;
                for (row..self.row_count) |r| {
                    if (self.data[r][col] != 0) {
                        pivot_row = r;
                        break;
                    }
                }

                if (pivot_row) |p_row| {
                    // the pivot for the Nth column should be in the Nth row
                    // if the pivot we chose isnt in the correct row we swap it
                    if (p_row != row) {
                        self.swapRows(p_row, row);
                    }

                    // now `row` contains the index of the row that contains the pivot

                    // scale the row so the leading coefficient is 1
                    if (self.data[p_row][col] != 1) {
                        self.scaleRow(row, 1 / self.data[p_row][col]);
                    }

                    // set all the other row leading coefficients to 0
                    for (0..self.row_count) |other_row| {
                        if (other_row == row) continue;
                        if (self.data[other_row][col] != 0) {
                            self.addRows(row, other_row, -self.data[other_row][col]);
                        }
                    }

                    row += 1;
                }
            }
        }
    };
}
