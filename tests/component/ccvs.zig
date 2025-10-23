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

test "isolated current controlled voltage source" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit();

    const gnd_id: usize = NetList.ground_node_id;

    // controller circuit
    const vs1_plus_id = try netlist.allocateNode();
    const v1: FloatType = 314.59;
    const r1: FloatType = 50;

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
    const ccvs_plus_id = try netlist.allocateNode();
    const vs2_plus_id = try netlist.allocateNode();
    const ccvs_transresistance: FloatType = 77.6;
    const v2: FloatType = 42.42;
    const r2: FloatType = 634.4;

    const v2_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .voltage_source = v2 },
        "V2",
        &.{ vs2_plus_id, gnd_id },
    );

    const controller_name = try gpa.dupe(u8, "R1");
    const ccvs_comp_idx = try netlist.addComponent(
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
        component.Component.Inner{ .resistor = r2 },
        "R2",
        &.{ ccvs_plus_id, gnd_id },
    );

    var res = try netlist.analyse(&.{
        v1_comp_idx,
        r1_comp_idx,
        v2_comp_idx,
        r2_comp_idx,
        ccvs_comp_idx,
    });
    defer res.deinit(netlist.allocator);

    // currents
    const controller_current = v1 / r1;
    try checkCurrent(&res, v1_comp_idx, controller_current);
    try checkCurrent(&res, r1_comp_idx, controller_current);

    const ccvs_voltage = ccvs_transresistance * controller_current;
    const r2_current = (ccvs_voltage + v2) / r2;
    try checkCurrent(&res, r2_comp_idx, r2_current);
    try checkCurrent(&res, v2_comp_idx, r2_current);
    try checkCurrent(&res, ccvs_comp_idx, r2_current);

    // voltages
    try checkVoltage(&res, gnd_id, 0);
    try checkVoltage(&res, vs1_plus_id, v1);
    try checkVoltage(&res, vs2_plus_id, v2);
    try checkVoltage(&res, ccvs_plus_id, v2 + ccvs_voltage);
}

test "coupled current controlled voltage source" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit();

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode();
    const ccvs_plus_id = try netlist.allocateNode();

    const v1: FloatType = 901.456;
    const r1: FloatType = 150.4;
    const ccvs_transresistance: FloatType = 3.4;
    const r2: FloatType = 333.33;

    const v1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .voltage_source = v1 },
        "V1",
        &.{ vs_plus_id, gnd_id },
    );

    const r1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .resistor = r1 },
        "R1",
        &.{ vs_plus_id, ccvs_plus_id },
    );

    const controller_name = try gpa.dupe(u8, "R1");
    const ccvs_comp_idx = try netlist.addComponent(
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
        component.Component.Inner{ .resistor = r2 },
        "R2",
        &.{ ccvs_plus_id, gnd_id },
    );

    var res = try netlist.analyse(&.{
        v1_comp_idx,
        r1_comp_idx,
        r2_comp_idx,
        ccvs_comp_idx,
    });
    defer res.deinit(netlist.allocator);

    // currents
    const r1_current = v1 / (r1 + ccvs_transresistance);
    const r2_current = ccvs_transresistance * r1_current / r2;
    const ccvs_current = r1_current - r2_current;
    try checkCurrent(&res, v1_comp_idx, -r1_current);
    try checkCurrent(&res, r1_comp_idx, r1_current);
    try checkCurrent(&res, r2_comp_idx, r2_current);
    try checkCurrent(&res, ccvs_comp_idx, ccvs_current);

    // voltages
    const ccvs_voltage = r1_current * ccvs_transresistance;
    try checkVoltage(&res, gnd_id, 0);
    try checkVoltage(&res, vs_plus_id, v1);
    try checkVoltage(&res, ccvs_plus_id, ccvs_voltage);
}
