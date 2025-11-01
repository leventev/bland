const std = @import("std");
const bland = @import("bland");
const main = @import("main.zig");

const Float = bland.Float;
const ComplexMatrix = bland.ComplexMatrix;
const Complex = std.math.Complex(Float);
const expectFloat = main.expectFloat;

fn z(comptime re: Float, comptime im: Float) Complex {
    return Complex{
        .re = re,
        .im = im,
    };
}

fn testMatrix(input: []const []const Complex, output: []const []const Complex) !void {
    const gpa = std.testing.allocator;
    var mat = try ComplexMatrix(Float).init(
        gpa,
        input.len,
        input[0].len,
    );
    defer mat.deinit(gpa);

    for (input, 0..) |row, row_idx| {
        for (row, 0..) |cell, col_idx| {
            mat.data[row_idx][col_idx] = cell;
        }
    }

    mat.gaussJordanElimination();

    for (output, 0..) |row, row_idx| {
        for (row, 0..) |expected, col_idx| {
            const actual = mat.data[row_idx][col_idx];
            try expectFloat(Float, expected.re, actual.re);
            try expectFloat(Float, expected.im, actual.im);
        }
    }
}

// source for the inputs: https://www.math.uwaterloo.ca/~jmckinno/Math225/Week9/Lecture3i.pdf

test "complex matrix 1" {
    const input: []const []const Complex = &.{
        &.{ z(1, 0), z(0, 1), z(-3, 1), z(-1, -1) },
        &.{ z(2, 0), z(1, 3), z(-4, 2), z(0, 2) },
        &.{ z(0, 2), z(-2, 0), z(-2, -3), z(-1, 1) },
    };

    const expected_output: []const []const Complex = &.{
        &.{ z(1, 0), z(0, 0), z(0, 0), z(4, 0) },
        &.{ z(0, 0), z(1, 0), z(0, 0), z(1, 1) },
        &.{ z(0, 0), z(0, 0), z(1, 0), z(1, 1) },
    };

    try testMatrix(input, expected_output);
}

test "complex matrix 2" {
    const input: []const []const Complex = &.{
        &.{ z(1, 0), z(1, 1), z(0, -2), z(-1, -1), z(2, 1) },
        &.{ z(1, -1), z(2, 0), z(-2, -1), z(-3, 1), z(1, -2) },
        &.{ z(0, 1), z(-1, 1), z(0, 1), z(-2, -2), z(-1, -3) },
    };

    const expected_output: []const []const Complex = &.{
        &.{ z(1, 0), z(1, 1), z(0, 0), z(-3, 1), z(-2, -1) },
        &.{ z(0, 0), z(0, 0), z(1, 0), z(1, 1), z(-1, 2) },
        &.{ z(0, 0), z(0, 0), z(0, 0), z(0, 0) },
    };

    try testMatrix(input, expected_output);
}
