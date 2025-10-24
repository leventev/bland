const std = @import("std");

const Complex = std.math.Complex;

fn complex_div(comptime T: type, a: Complex(T), b: Complex(T)) Complex(T) {
    // multiplying by 1/z is the same as multiplying by conj(z)/(|z|^2)
    // so a/b -> a*conj(b)/(|b|^2)
    return a.mul(b.reciprocal());
}

pub fn ComplexMatrix(comptime T: type) type {
    return struct {
        row_count: usize,
        col_count: usize,
        // first index is row, second index is column
        data: [][]Complex(T),

        pub fn init(
            allocator: std.mem.Allocator,
            row_count: usize,
            col_count: usize,
        ) !ComplexMatrix(T) {
            var data: [][]Complex(T) = try allocator.alloc([]Complex(T), row_count);
            // maybe do a single allocation for all rows and then just slice them?
            for (0..row_count) |i| {
                data[i] = try allocator.alloc(Complex(T), col_count);
            }

            return ComplexMatrix(T){
                .col_count = col_count,
                .row_count = row_count,
                .data = data,
            };
        }

        pub fn deinit(self: *ComplexMatrix(T), allocator: std.mem.Allocator) void {
            for (0..self.row_count) |i| {
                allocator.free(self.data[i]);
                self.data[i] = undefined;
            }

            allocator.free(self.data);
            self.data = undefined;
            self.row_count = 0;
            self.col_count = 0;
        }

        pub fn dump(self: ComplexMatrix(T)) void {
            for (0..self.row_count) |row| {
                for (0..self.col_count) |col| {
                    const c = self.data[row][col];
                    if (c.im == 0) {
                        std.debug.print("({}) ", .{c.re});
                    } else if (c.im < 0) {
                        std.debug.print("({} - j{}) ", .{ c.re, -c.im });
                    } else {
                        std.debug.print("({} + j{}) ", .{ c.re, c.im });
                    }
                }
                std.debug.print("\n", .{});
            }
        }

        pub fn swapRows(self: *ComplexMatrix(T), row1: usize, row2: usize) void {
            std.debug.assert(row1 < self.row_count);
            std.debug.assert(row2 < self.row_count);
            const temp = self.data[row1];
            self.data[row1] = self.data[row2];
            self.data[row2] = temp;
        }

        pub fn scaleRow(self: *ComplexMatrix(T), row: usize, scale: Complex(T)) void {
            std.debug.assert(row < self.row_count);
            for (0..self.col_count) |col| {
                self.data[row][col] = self.data[row][col].mul(scale);
            }
        }

        // row2 = row2 + scale * row1
        pub fn addRows(self: *ComplexMatrix(T), row1: usize, row2: usize, scale: Complex(T)) void {
            std.debug.assert(row1 < self.row_count);
            std.debug.assert(row2 < self.row_count);
            for (0..self.col_count) |col| {
                self.data[row2][col] = self.data[row2][col].add(
                    self.data[row1][col].mul(scale),
                );
            }
        }

        pub fn gaussJordanElimination(self: *ComplexMatrix(T)) void {
            var row: usize = 0;
            var col: usize = 0;

            while (row < self.row_count and col < self.col_count) : (col += 1) {
                // find the first non empty row and use that as the pivot
                var pivot_row: ?usize = null;
                for (row..self.row_count) |r| {
                    if (self.data[r][col].magnitude() != 0) {
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

                    // set all the other row leading coefficients to 0
                    for (0..self.row_count) |other_row| {
                        if (other_row == row) continue;

                        const pivot_z = self.data[row][col];
                        const other_z = self.data[other_row][col];

                        const scale = complex_div(T, other_z, pivot_z).neg();

                        if (self.data[other_row][col].magnitude() != 0) {
                            self.addRows(row, other_row, scale);
                        }
                    }

                    // scale the row so the leading coefficient is 1
                    const pivot_value = self.data[row][col];
                    if (pivot_value.re != 1 or pivot_value.im != 0) {
                        const reciprocal = pivot_value.reciprocal();
                        self.scaleRow(row, reciprocal);
                    }

                    row += 1;
                }
            }
        }
    };
}
