const std = @import("std");
const bland = @import("bland");
const circuit = bland.circuit;

const NetList = bland.NetList;
const FloatType = circuit.FloatType;

const tolerance = 1e-6;

pub fn checkCurrent(
    res: *const NetList.AnalysationResult,
    current_id: usize,
    expected: FloatType,
) !void {
    // TODO: check polarity???
    try std.testing.expect(current_id < res.currents.len);
    try std.testing.expect(res.currents[current_id] != null);
    const actual = res.currents[current_id].?;

    const expected_abs = @abs(expected);
    const expected_actual = @abs(actual);
    try std.testing.expectApproxEqRel(expected_abs, expected_actual, tolerance);
}

pub fn checkVoltage(
    res: *const NetList.AnalysationResult,
    node_id: usize,
    expected: FloatType,
) !void {
    try std.testing.expect(node_id < res.voltages.len);
    const actual = res.voltages[node_id];
    try std.testing.expectApproxEqRel(expected, actual, tolerance);
}

pub fn checkVoltage2(
    res: *const NetList.AnalysationResult,
    node1_id: usize,
    node2_id: usize,
    expected: FloatType,
) !void {
    try std.testing.expect(node1_id < res.voltages.len);
    try std.testing.expect(node2_id < res.voltages.len);
    const actual = res.voltages[node1_id] - res.voltages[node2_id];
    try std.testing.expectApproxEqRel(expected, actual, tolerance);
}

comptime {
    _ = @import("component/resistor.zig");
    _ = @import("component/ccvs.zig");
}
