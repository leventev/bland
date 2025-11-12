const std = @import("std");
const bland = @import("bland");
const circuit_testing = @import("../circuit_tests.zig");

const Component = bland.Component;
const NetList = bland.NetList;
const Float = bland.Float;

const checkCurrentDC = circuit_testing.checkCurrentDC;
const checkVoltageDC = circuit_testing.checkVoltageDC;
const checkVoltage2DC = circuit_testing.checkVoltage2DC;

test "isolated current controlled current source" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;

    // controller circuit
    const vs1_plus_id = try netlist.allocateNode(gpa);
    const v1: Float = 813.91;
    const r1: Float = 966.2222;

    const v1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .voltage_source = v1 },
        "V1",
        &.{ vs1_plus_id, gnd_id },
    );

    const r1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .resistor = r1 },
        "R1",
        &.{ vs1_plus_id, gnd_id },
    );

    // ccvs circuit
    const cccs_plus_id = try netlist.allocateNode(gpa);
    const cccs_neg_id = try netlist.allocateNode(gpa);
    const cccs_multiplier: Float = 8.443;
    const r2: Float = 470;
    const r3: Float = 6988.5;

    const r2_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .resistor = r2 },
        "R2",
        &.{ cccs_neg_id, gnd_id },
    );

    const r3_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .resistor = r3 },
        "R3",
        &.{ cccs_plus_id, gnd_id },
    );

    const cccs_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .cccs = .{
            .controller_comp_id = r1_comp_idx,
            .multiplier = cccs_multiplier,
        } },
        "CCCS1",
        &.{ cccs_plus_id, cccs_neg_id },
    );

    var res = try netlist.analyseDC(
        gpa,
        &.{
            v1_comp_idx,
            r1_comp_idx,
            r2_comp_idx,
            r3_comp_idx,
            cccs_comp_idx,
        },
    );
    defer res.deinit(gpa);

    // currents
    const controller_current = v1 / r1;
    try checkCurrentDC(&res, v1_comp_idx, controller_current);
    try checkCurrentDC(&res, r1_comp_idx, controller_current);

    const cccs_current = cccs_multiplier * controller_current;
    try checkCurrentDC(&res, r2_comp_idx, cccs_current);
    try checkCurrentDC(&res, r3_comp_idx, cccs_current);
    try checkCurrentDC(&res, cccs_comp_idx, cccs_current);

    // voltages
    const r2_voltage = cccs_current * r2;
    const r3_voltage = -cccs_current * r3;
    try checkVoltageDC(&res, gnd_id, 0);
    try checkVoltageDC(&res, vs1_plus_id, v1);
    try checkVoltageDC(&res, cccs_neg_id, r2_voltage);
    try checkVoltageDC(&res, cccs_plus_id, r3_voltage);
}

test "coupled current controlled current source" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode(gpa);
    const cccs_plus_id = try netlist.allocateNode(gpa);

    const v1: Float = 33.3;
    const r1: Float = 6.919;
    const cccs_multiplier: Float = 5.4;
    const r2: Float = 36.8;

    const v1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .voltage_source = v1 },
        "V1",
        &.{ vs_plus_id, gnd_id },
    );

    const r1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .resistor = r1 },
        "R1",
        &.{ vs_plus_id, cccs_plus_id },
    );

    const r2_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .resistor = r2 },
        "R2",
        &.{ cccs_plus_id, gnd_id },
    );

    const cccs_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .cccs = .{
            .controller_comp_id = r1_comp_idx,
            .multiplier = cccs_multiplier,
        } },
        "CCCS1",
        &.{ gnd_id, cccs_plus_id },
    );

    var res = try netlist.analyseDC(
        gpa,
        &.{
            v1_comp_idx,
            r1_comp_idx,
            r2_comp_idx,
            cccs_comp_idx,
        },
    );
    defer res.deinit(gpa);

    // currents
    const r1_current = v1 / (r1 + r2 * (cccs_multiplier + 1));
    const cccs_current = r1_current * cccs_multiplier;
    const r2_current = cccs_current + r1_current;
    try checkCurrentDC(&res, v1_comp_idx, -r1_current);
    try checkCurrentDC(&res, r1_comp_idx, r1_current);
    try checkCurrentDC(&res, r2_comp_idx, r2_current);
    try checkCurrentDC(&res, cccs_comp_idx, cccs_current);

    // voltages
    const cccs_voltage = r2_current * r2;
    try checkVoltageDC(&res, gnd_id, 0);
    try checkVoltageDC(&res, vs_plus_id, v1);
    try checkVoltageDC(&res, cccs_plus_id, cccs_voltage);
}
