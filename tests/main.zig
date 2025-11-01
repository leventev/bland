const std = @import("std");
const bland = @import("bland");

const tolerance = 1e-6;

pub fn expectFloat(comptime T: type, expected: T, actual: T) !void {
    if (expected == 0) {
        try std.testing.expectApproxEqAbs(expected, actual, tolerance);
    } else {
        try std.testing.expectApproxEqRel(expected, actual, tolerance);
    }
}

comptime {
    std.testing.refAllDeclsRecursive(bland);

    _ = @import("circuit_tests.zig");
    _ = @import("complex_matrix_tests.zig");
}
