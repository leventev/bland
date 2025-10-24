const std = @import("std");

const tolerance = 1e-6;

pub fn expectFloat(comptime T: type, expected: T, actual: T) !void {
    if (expected == 0) {
        try std.testing.expectApproxEqAbs(expected, actual, tolerance);
    } else {
        try std.testing.expectApproxEqRel(expected, actual, tolerance);
    }
}

comptime {
    _ = @import("circuit_tests.zig");
    _ = @import("complex_matrix_tests.zig");
}
