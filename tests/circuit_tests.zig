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
    report: *const NetList.RealAnalysisResult,
    current_id: bland.Component.Id,
    expected: Float,
) !void {
    // TODO: check polarity???
    const current_id_int = @intFromEnum(current_id);
    try std.testing.expect(current_id_int < report.currents.len);
    try std.testing.expect(report.currents[current_id_int] != null);

    const actual = report.currents[current_id_int].?;

    const expected_abs = @abs(expected);
    const expected_actual = @abs(actual);
    try expectFloat(Float, expected_abs, expected_actual);
}

pub fn checkVoltageDC(
    report: *const NetList.RealAnalysisResult,
    node_id: NetList.Node.Id,
    expected: Float,
) !void {
    const node_id_int = @intFromEnum(node_id);
    try std.testing.expect(node_id_int < report.voltages.len);
    const actual = report.voltages[node_id_int];
    try expectFloat(Float, expected, actual);
}

pub fn checkVoltage2DC(
    report: *const NetList.RealAnalysisResult,
    node1_id: NetList.Node.Id,
    node2_id: NetList.Node.Id,
    expected: Float,
) !void {
    const node1_id_int = @intFromEnum(node1_id);
    const node2_id_int = @intFromEnum(node2_id);
    try std.testing.expect(node1_id_int < report.voltages.len);
    try std.testing.expect(node2_id_int < report.voltages.len);
    const actual = report.voltages[node1_id_int] - report.voltages[node2_id_int];
    try expectFloat(Float, expected, actual);
}

pub fn checkVoltageAC(
    report: *const NetList.ComplexAnalysisReport,
    node_id: NetList.Node.Id,
    expected: Complex,
) !void {
    const node_id_int = @intFromEnum(node_id);
    try std.testing.expect(node_id_int < report.voltages.len);
    const actual = report.voltages[node_id_int];
    try expectComplex(expected, actual);
}

pub fn checkVoltage2AC(
    report: *const NetList.ComplexAnalysisReport,
    node1_id: NetList.Node.Id,
    node2_id: NetList.Node.Id,
    expected: Complex,
) !void {
    const node1_id_int = @intFromEnum(node1_id);
    const node2_id_int = @intFromEnum(node2_id);
    try std.testing.expect(node1_id_int < report.voltages.len);
    try std.testing.expect(node2_id_int < report.voltages.len);
    const actual = report.voltages[node1_id_int].sub(report.voltages[node2_id_int]);
    try expectComplex(expected, actual);
}

pub fn checkCurrentAC(
    report: *const NetList.ComplexAnalysisReport,
    current_id: bland.Component.Id,
    expected: Complex,
) !void {
    const current_id_int = @intFromEnum(current_id);
    try std.testing.expect(current_id_int < report.currents.len);
    try std.testing.expect(report.currents[current_id_int] != null);

    const actual = report.currents[current_id_int].?;
    try expectComplex(expected, actual);
}

comptime {
    _ = @import("component/resistor.zig");
    _ = @import("component/ccvs.zig");
    _ = @import("component/cccs.zig");
    _ = @import("component/capacitor.zig");
    _ = @import("component/inductor.zig");
    _ = @import("component/rlc.zig");
}
