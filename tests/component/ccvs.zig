const std = @import("std");
const bland = @import("bland");
const circuit_testing = @import("../circuit_tests.zig");
const circuit = bland.circuit;
const component = bland.component;

const NetList = bland.NetList;
const FloatType = circuit.FloatType;
const checkCurrentDC = circuit_testing.checkCurrentDC;
const checkVoltageDC = circuit_testing.checkVoltageDC;
const checkVoltage2DC = circuit_testing.checkVoltage2DC;

test "isolated current controlled voltage source" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;

    // controller circuit
    const vs1_plus_id = try netlist.allocateNode(gpa);
    const v1: FloatType = 314.59;
    const r1: FloatType = 50;

    const v1_comp_idx = try netlist.addComponent(
        gpa,
        component.Component.Inner{ .voltage_source = v1 },
        "V1",
        &.{ vs1_plus_id, gnd_id },
    );

    const r1_comp_idx = try netlist.addComponent(
        gpa,
        component.Component.Inner{ .resistor = r1 },
        "R1",
        &.{ vs1_plus_id, gnd_id },
    );

    // ccvs circuit
    const ccvs_plus_id = try netlist.allocateNode(gpa);
    const vs2_plus_id = try netlist.allocateNode(gpa);
    const ccvs_transresistance: FloatType = 77.6;
    const v2: FloatType = 42.42;
    const r2: FloatType = 634.4;

    const v2_comp_idx = try netlist.addComponent(
        gpa,
        component.Component.Inner{ .voltage_source = v2 },
        "V2",
        &.{ vs2_plus_id, gnd_id },
    );

    const controller_name = try gpa.dupe(u8, "R1");
    const ccvs_comp_idx = try netlist.addComponent(
        gpa,
        component.Component.Inner{ .ccvs = .{
            .controller_name_buff = controller_name,
            .controller_name = controller_name,
            .transresistance = ccvs_transresistance,
            .controller_group_2_idx = null,
        } },
        "CCVS1",
        &.{ ccvs_plus_id, vs2_plus_id },
    );

    const r2_comp_idx = try netlist.addComponent(
        gpa,
        component.Component.Inner{ .resistor = r2 },
        "R2",
        &.{ ccvs_plus_id, gnd_id },
    );

    var res = try netlist.analyseDC(
        gpa,
        &.{
            v1_comp_idx,
            r1_comp_idx,
            v2_comp_idx,
            r2_comp_idx,
            ccvs_comp_idx,
        },
    );
    defer res.deinit(gpa);

    // currents
    const controller_current = v1 / r1;
    try checkCurrentDC(&res, v1_comp_idx, controller_current);
    try checkCurrentDC(&res, r1_comp_idx, controller_current);

    const ccvs_voltage = ccvs_transresistance * controller_current;
    const r2_current = (ccvs_voltage + v2) / r2;
    try checkCurrentDC(&res, r2_comp_idx, r2_current);
    try checkCurrentDC(&res, v2_comp_idx, r2_current);
    try checkCurrentDC(&res, ccvs_comp_idx, r2_current);

    // voltages
    try checkVoltageDC(&res, gnd_id, 0);
    try checkVoltageDC(&res, vs1_plus_id, v1);
    try checkVoltageDC(&res, vs2_plus_id, v2);
    try checkVoltageDC(&res, ccvs_plus_id, v2 + ccvs_voltage);
}

test "coupled current controlled voltage source" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode(gpa);
    const ccvs_plus_id = try netlist.allocateNode(gpa);

    const v1: FloatType = 901.456;
    const r1: FloatType = 150.4;
    const ccvs_transresistance: FloatType = 3.4;
    const r2: FloatType = 333.33;

    const v1_comp_idx = try netlist.addComponent(
        gpa,
        component.Component.Inner{ .voltage_source = v1 },
        "V1",
        &.{ vs_plus_id, gnd_id },
    );

    const r1_comp_idx = try netlist.addComponent(
        gpa,
        component.Component.Inner{ .resistor = r1 },
        "R1",
        &.{ vs_plus_id, ccvs_plus_id },
    );

    const controller_name = try gpa.dupe(u8, "R1");
    const ccvs_comp_idx = try netlist.addComponent(
        gpa,
        component.Component.Inner{ .ccvs = .{
            .controller_name_buff = controller_name,
            .controller_name = controller_name,
            .transresistance = ccvs_transresistance,
            .controller_group_2_idx = null,
        } },
        "CCVS1",
        &.{ ccvs_plus_id, gnd_id },
    );

    const r2_comp_idx = try netlist.addComponent(
        gpa,
        component.Component.Inner{ .resistor = r2 },
        "R2",
        &.{ ccvs_plus_id, gnd_id },
    );

    var res = try netlist.analyseDC(
        gpa,
        &.{
            v1_comp_idx,
            r1_comp_idx,
            r2_comp_idx,
            ccvs_comp_idx,
        },
    );
    defer res.deinit(gpa);

    // currents
    const r1_current = v1 / (r1 + ccvs_transresistance);
    const r2_current = ccvs_transresistance * r1_current / r2;
    const ccvs_current = r1_current - r2_current;
    try checkCurrentDC(&res, v1_comp_idx, -r1_current);
    try checkCurrentDC(&res, r1_comp_idx, r1_current);
    try checkCurrentDC(&res, r2_comp_idx, r2_current);
    try checkCurrentDC(&res, ccvs_comp_idx, ccvs_current);

    // voltages
    const ccvs_voltage = r1_current * ccvs_transresistance;
    try checkVoltageDC(&res, gnd_id, 0);
    try checkVoltageDC(&res, vs_plus_id, v1);
    try checkVoltageDC(&res, ccvs_plus_id, ccvs_voltage);
}
