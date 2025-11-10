const std = @import("std");
const bland = @import("bland");
const units = bland.units;

const TestCase = struct {
    unit: units.Unit,
    val: bland.Float,
    precision: usize,
    expected: []const u8,
};

const test_cases = [_]TestCase{
    .{ .unit = .voltage, .val = 1500, .precision = 2, .expected = "1.50kV" },
    .{ .unit = .current, .val = 4.869e9, .precision = 2, .expected = "4.87GA" },
    .{ .unit = .power, .val = 6.89536, .precision = 4, .expected = "6.8954W" },
    .{ .unit = .power, .val = 3.549e-3, .precision = 4, .expected = "3.5490mW" },
    .{ .unit = .capacitance, .val = 48.44e-12, .precision = 6, .expected = "48.440000pF" },
    .{ .unit = .dimensionless, .val = 68.5345, .precision = 2, .expected = "68.53" },
    .{ .unit = .capacitance, .val = 53.83e-18, .precision = 1, .expected = "5.4e-17F" },
    .{ .unit = .inductance, .val = 4.5e18, .precision = 1, .expected = "4500.0PH" },
    .{ .unit = .current, .val = -6e-3, .precision = 1, .expected = "-6.0mA" },
    .{ .unit = .voltage, .val = 1, .precision = 0, .expected = "1V" },
    .{ .unit = .current, .val = 0, .precision = 0, .expected = "0A" },
    .{ .unit = .dimensionless, .val = 0, .precision = 0, .expected = "0" },
};

test "unit formatting with prealloced buffer" {
    var buff: [256]u8 = undefined;

    inline for (test_cases) |test_case| {
        const res = try units.formatUnitBuf(
            &buff,
            test_case.unit,
            test_case.val,
            test_case.precision,
        );

        try std.testing.expectEqualStrings(test_case.expected, res);
    }
}

test "unit formatting with alloc" {
    const alloc = std.testing.allocator;

    inline for (test_cases) |test_case| {
        const res = try units.formatUnitAlloc(
            alloc,
            test_case.unit,
            test_case.val,
            test_case.precision,
        );

        try std.testing.expectEqualStrings(test_case.expected, res);
        alloc.free(res);
    }
}
