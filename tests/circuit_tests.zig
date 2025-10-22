const std = @import("std");
const bland = @import("bland");
const circuit = bland.circuit;
const component = bland.component;

const NetList = circuit.NetList;

const tolerance = 1e-6;

fn checkCurrent(
    res: *const NetList.AnalysationResult,
    current_id: usize,
    expected: circuit.FloatType,
) !void {
    // TODO: check polarity???
    try std.testing.expect(current_id < res.currents.len);
    try std.testing.expect(res.currents[current_id] != null);
    const actual = res.currents[current_id].?;

    const expected_abs = @abs(expected);
    const expected_actual = @abs(actual);
    try std.testing.expectApproxEqRel(expected_abs, expected_actual, tolerance);
}

fn checkVoltage(
    res: *const NetList.AnalysationResult,
    voltage_id: usize,
    expected: circuit.FloatType,
) !void {
    try std.testing.expect(voltage_id < res.voltages.len);
    const actual = res.voltages[voltage_id];
    try std.testing.expectApproxEqRel(expected, actual, tolerance);
}

test "single resistor" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit();

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode();

    const v1 = 11.46;
    const r1 = 34.6898;

    const v1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .voltage_source = v1 },
        "V1",
        &.{ vs_plus_id, gnd_id },
    );

    const r1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .resistor = r1 },
        "R1",
        &.{ vs_plus_id, gnd_id },
    );

    var res = try netlist.analyse(&.{ v1_comp_idx, r1_comp_idx });
    defer res.deinit(netlist.allocator);

    // currents
    const current = v1 / r1;
    try checkCurrent(&res, v1_comp_idx, current);
    try checkCurrent(&res, r1_comp_idx, current);

    // voltages
    try checkVoltage(&res, gnd_id, 0);
    try checkVoltage(&res, vs_plus_id, v1);
}

test "voltage divider" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit();

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode();
    const middle_id = try netlist.allocateNode();

    const v1 = 5.0;
    const r1 = 24.5;
    const r2 = 343.5;

    const v1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .voltage_source = v1 },
        "V1",
        &.{ vs_plus_id, gnd_id },
    );

    const r1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .resistor = r1 },
        "R1",
        &.{ middle_id, vs_plus_id },
    );

    const r2_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .resistor = r2 },
        "R2",
        &.{ gnd_id, middle_id },
    );

    var res = try netlist.analyse(&.{ v1_comp_idx, r1_comp_idx, r2_comp_idx });
    defer res.deinit(netlist.allocator);

    // currents
    const current = v1 / (r1 + r2);
    try checkCurrent(&res, v1_comp_idx, current);
    try checkCurrent(&res, r1_comp_idx, current);
    try checkCurrent(&res, r2_comp_idx, current);

    // voltages
    try checkVoltage(&res, gnd_id, 0);
    try checkVoltage(&res, vs_plus_id, v1);
    const middle_node_voltage = v1 * (r2 / (r1 + r2));
    try checkVoltage(&res, middle_id, middle_node_voltage);
}
