const std = @import("std");
const bland = @import("bland");
const main = @import("main.zig");

// TODO: export types and such in a nicer way
const NetList = bland.NetList;
const Float = bland.Float;
const expectFloat = main.expectFloat;
const Complex = std.math.Complex(Float);

pub fn checkCurrentDC(
    report: *const NetList.AnalysisReport,
    current_id: usize,
    expected: Float,
) !void {
    // TODO: check polarity???

    const res = report.values.dc;
    try std.testing.expect(current_id < res.currents.len);
    try std.testing.expect(res.currents[current_id] != null);

    const actual = res.currents[current_id].?;

    const expected_abs = @abs(expected);
    const expected_actual = @abs(actual);
    try expectFloat(Float, expected_abs, expected_actual);
}

pub fn checkVoltageDC(
    report: *const NetList.AnalysisReport,
    node_id: usize,
    expected: Float,
) !void {
    const res = report.values.dc;

    try std.testing.expect(node_id < res.voltages.len);
    const actual = res.voltages[node_id];
    try expectFloat(Float, expected, actual);
}

pub fn checkVoltage2DC(
    report: *const NetList.AnalysisReport,
    node1_id: usize,
    node2_id: usize,
    expected: Float,
) !void {
    const res = report.values.dc;

    try std.testing.expect(node1_id < res.voltages.len);
    try std.testing.expect(node2_id < res.voltages.len);
    const actual = res.voltages[node1_id] - res.voltages[node2_id];
    try expectFloat(Float, expected, actual);
}

comptime {
    _ = @import("component/resistor.zig");
    _ = @import("component/ccvs.zig");
    _ = @import("component/cccs.zig");
}
