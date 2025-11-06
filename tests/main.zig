const std = @import("std");
const bland = @import("bland");

const tolerance = 1e-2;

pub const Float = bland.Float;
pub const Complex = std.math.Complex(Float);

pub fn expectFloat(comptime T: type, expected: T, actual: T) !void {
    if (expected == 0 or actual == 0) {
        try std.testing.expectApproxEqAbs(expected, actual, tolerance);
    } else {
        try std.testing.expectApproxEqRel(expected, actual, tolerance);
    }
}

pub fn expectComplex(expected: Complex, actual: Complex) !void {
    try expectFloat(Float, expected.re, actual.re);
    try expectFloat(Float, expected.im, actual.im);
}

comptime {
    std.testing.refAllDeclsRecursive(bland);

    _ = @import("circuit_tests.zig");
    _ = @import("complex_matrix_tests.zig");
}
