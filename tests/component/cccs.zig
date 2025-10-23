const std = @import("std");
const bland = @import("bland");
const circuit_testing = @import("../circuit_tests.zig");
const circuit = bland.circuit;
const component = bland.component;

const NetList = bland.NetList;
const FloatType = circuit.FloatType;
const checkCurrent = circuit_testing.checkCurrent;
const checkVoltage = circuit_testing.checkVoltage;
const checkVoltage2 = circuit_testing.checkVoltage2;

test "isolated current controlled current source" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit();

    const gnd_id: usize = NetList.ground_node_id;

    // controller circuit
    const vs1_plus_id = try netlist.allocateNode();
    const v1: FloatType = 813.91;
    const r1: FloatType = 966.2222;

    const v1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .voltage_source = v1 },
        "V1",
        &.{ vs1_plus_id, gnd_id },
    );

    const r1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .resistor = r1 },
        "R1",
        &.{ vs1_plus_id, gnd_id },
    );

    // ccvs circuit
    const cccs_plus_id = try netlist.allocateNode();
    const cccs_neg_id = try netlist.allocateNode();
    const cccs_multiplier: FloatType = 8.443;
    const r2: FloatType = 470;
    const r3: FloatType = 6988.5;

    const r2_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .resistor = r2 },
        "R2",
        &.{ cccs_neg_id, gnd_id },
    );

    const r3_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .resistor = r3 },
        "R3",
        &.{ cccs_plus_id, gnd_id },
    );

    const controller_name = try gpa.dupe(u8, "R1");
    const cccs_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .cccs = .{
            .controller_name_buff = controller_name,
            .controller_name = controller_name,
            .multiplier = cccs_multiplier,
            .controller_group_2_idx = null,
        } },
        "CCCS1",
        &.{ cccs_plus_id, cccs_neg_id },
    );

    var res = try netlist.analyse(&.{
        v1_comp_idx,
        r1_comp_idx,
        r2_comp_idx,
        r3_comp_idx,
        cccs_comp_idx,
    });
    defer res.deinit(netlist.allocator);

    // currents
    const controller_current = v1 / r1;
    try checkCurrent(&res, v1_comp_idx, controller_current);
    try checkCurrent(&res, r1_comp_idx, controller_current);

    const cccs_current = cccs_multiplier * controller_current;
    try checkCurrent(&res, r2_comp_idx, cccs_current);
    try checkCurrent(&res, r3_comp_idx, cccs_current);
    try checkCurrent(&res, cccs_comp_idx, cccs_current);

    // voltages
    const r2_voltage = cccs_current * r2;
    const r3_voltage = -cccs_current * r3;
    try checkVoltage(&res, gnd_id, 0);
    try checkVoltage(&res, vs1_plus_id, v1);
    try checkVoltage(&res, cccs_neg_id, r2_voltage);
    try checkVoltage(&res, cccs_plus_id, r3_voltage);
}

test "coupled current controlled current source" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit();

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode();
    const cccs_plus_id = try netlist.allocateNode();

    const v1: FloatType = 33.3;
    const r1: FloatType = 6.919;
    const cccs_multiplier: FloatType = 5.4;
    const r2: FloatType = 36.8;

    const v1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .voltage_source = v1 },
        "V1",
        &.{ vs_plus_id, gnd_id },
    );

    const r1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .resistor = r1 },
        "R1",
        &.{ vs_plus_id, cccs_plus_id },
    );

    const r2_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .resistor = r2 },
        "R2",
        &.{ cccs_plus_id, gnd_id },
    );

    const controller_name = try gpa.dupe(u8, "R1");
    const cccs_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .cccs = .{
            .controller_name_buff = controller_name,
            .controller_name = controller_name,
            .multiplier = cccs_multiplier,
            .controller_group_2_idx = null,
        } },
        "CCCS1",
        &.{ gnd_id, cccs_plus_id },
    );

    var res = try netlist.analyse(&.{
        v1_comp_idx,
        r1_comp_idx,
        r2_comp_idx,
        cccs_comp_idx,
    });
    defer res.deinit(netlist.allocator);

    // currents
    const r1_current = v1 / (r1 + r2 * (cccs_multiplier + 1));
    const cccs_current = r1_current * cccs_multiplier;
    const r2_current = cccs_current + r1_current;
    try checkCurrent(&res, v1_comp_idx, -r1_current);
    try checkCurrent(&res, r1_comp_idx, r1_current);
    try checkCurrent(&res, r2_comp_idx, r2_current);
    try checkCurrent(&res, cccs_comp_idx, cccs_current);

    // voltages
    const cccs_voltage = r2_current * r2;
    try checkVoltage(&res, gnd_id, 0);
    try checkVoltage(&res, vs_plus_id, v1);
    try checkVoltage(&res, cccs_plus_id, cccs_voltage);
}
