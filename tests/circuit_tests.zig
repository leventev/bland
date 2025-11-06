const std = @import("std");
const bland = @import("bland");
const main = @import("main.zig");

// TODO: export types and such in a nicer way
const NetList = bland.NetList;
const Float = main.Float;
const Complex = main.Complex;
const expectFloat = main.expectFloat;
const expectComplex = main.expectComplex;

pub fn checkCurrentDC(
    report: *const NetList.DCAnalysisReport,
    current_id: usize,
    expected: Float,
) !void {
    // TODO: check polarity???
    try std.testing.expect(current_id < report.currents.len);
    try std.testing.expect(report.currents[current_id] != null);

    const actual = report.currents[current_id].?;

    const expected_abs = @abs(expected);
    const expected_actual = @abs(actual);
    try expectFloat(Float, expected_abs, expected_actual);
}

pub fn checkVoltageDC(
    report: *const NetList.DCAnalysisReport,
    node_id: usize,
    expected: Float,
) !void {
    try std.testing.expect(node_id < report.voltages.len);
    const actual = report.voltages[node_id];
    try expectFloat(Float, expected, actual);
}

pub fn checkVoltage2DC(
    report: *const NetList.DCAnalysisReport,
    node1_id: usize,
    node2_id: usize,
    expected: Float,
) !void {
    try std.testing.expect(node1_id < report.voltages.len);
    try std.testing.expect(node2_id < report.voltages.len);
    const actual = report.voltages[node1_id] - report.voltages[node2_id];
    try expectFloat(Float, expected, actual);
}

pub fn checkVoltageAC(
    report: *const NetList.ACAnalysisReport,
    node_id: usize,
    expected: Complex,
) !void {
    try std.testing.expect(node_id < report.voltages.len);
    const actual = report.voltages[node_id];
    try expectComplex(expected, actual);
}

pub fn checkVoltage2AC(
    report: *const NetList.ACAnalysisReport,
    node1_id: usize,
    node2_id: usize,
    expected: Complex,
) !void {
    try std.testing.expect(node1_id < report.voltages.len);
    try std.testing.expect(node2_id < report.voltages.len);
    const actual = report.voltages[node1_id].sub(report.voltages[node2_id]);
    try expectComplex(expected, actual);
}

pub fn checkCurrentAC(
    report: *const NetList.ACAnalysisReport,
    current_id: usize,
    expected: Complex,
) !void {
    try std.testing.expect(current_id < report.currents.len);
    try std.testing.expect(report.currents[current_id] != null);

    const actual = report.currents[current_id].?;
    try expectComplex(expected, actual);
}

comptime {
    _ = @import("component/resistor.zig");
    _ = @import("component/ccvs.zig");
    _ = @import("component/cccs.zig");
    _ = @import("component/capacitor.zig");
}
