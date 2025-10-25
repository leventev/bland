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

test "ohm's law" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit();

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode();

    const v1: FloatType = 11.46;
    const r1: FloatType = 34.6898;

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

    var res = try netlist.analyse(&.{ v1_comp_idx, r1_comp_idx }, 0);
    defer res.deinit(netlist.allocator);

    // currents
    const current = v1 / r1;
    try checkCurrentDC(&res, v1_comp_idx, current);
    try checkCurrentDC(&res, r1_comp_idx, current);

    // voltages
    try checkVoltageDC(&res, gnd_id, 0);
    try checkVoltageDC(&res, vs_plus_id, v1);
}

test "voltage divider" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit();

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode();
    const middle_id = try netlist.allocateNode();

    const v1: FloatType = 5.0;
    const r1: FloatType = 24.5;
    const r2: FloatType = 343.5;

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

    var res = try netlist.analyse(&.{ v1_comp_idx, r1_comp_idx, r2_comp_idx }, 0);
    defer res.deinit(netlist.allocator);

    // currents
    const current = v1 / (r1 + r2);
    try checkCurrentDC(&res, v1_comp_idx, current);
    try checkCurrentDC(&res, r1_comp_idx, current);
    try checkCurrentDC(&res, r2_comp_idx, current);

    // voltages
    const middle_node_voltage = v1 * (r2 / (r1 + r2));
    try checkVoltageDC(&res, gnd_id, 0);
    try checkVoltageDC(&res, vs_plus_id, v1);
    try checkVoltageDC(&res, middle_id, middle_node_voltage);
}

test "voltage divider many" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit();

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode();

    const v1: FloatType = 137.53;

    const r_list = [_]FloatType{
        46.3,
        0.67,
        10000,
        304.5,
        9.998,
        4.5,
        800,
    };
    var r_comp_idxs: [r_list.len]usize = undefined;

    // there are N-1 nodes between N resistors but we append
    // the ground node at the end so its easier to add resistors
    var node_ids: [r_list.len]usize = undefined;
    for (0..node_ids.len - 1) |i| {
        node_ids[i] = try netlist.allocateNode();
    }
    node_ids[r_list.len - 1] = gnd_id;

    var positive_side_node = vs_plus_id;
    inline for (r_list, 0..) |resistance, i| {
        const negative_side_node = node_ids[i];
        r_comp_idxs[i] = try netlist.addComponent(
            .{ .resistor = resistance },
            std.fmt.comptimePrint("R{}", .{i + 1}),
            &.{ positive_side_node, negative_side_node },
        );
        positive_side_node = negative_side_node;
    }

    const v1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .voltage_source = v1 },
        "V1",
        &.{ vs_plus_id, gnd_id },
    );

    const currents_watched = .{v1_comp_idx} ++ r_comp_idxs;
    var res = try netlist.analyse(&currents_watched, 0);
    defer res.deinit(netlist.allocator);

    comptime var total_resistance: FloatType = 0;
    comptime for (r_list) |r| {
        total_resistance += r;
    };

    // currents
    const current = v1 / total_resistance;
    for (currents_watched) |comp_idx| {
        try checkCurrentDC(&res, comp_idx, current);
    }

    // voltages
    positive_side_node = vs_plus_id;
    try checkVoltageDC(&res, gnd_id, 0);
    try checkVoltageDC(&res, vs_plus_id, v1);

    positive_side_node = vs_plus_id;
    for (r_list, 0..) |resistance, i| {
        const negative_side_node = node_ids[i];
        const voltage = v1 * (resistance / total_resistance);
        try checkVoltage2DC(&res, positive_side_node, negative_side_node, voltage);
        positive_side_node = negative_side_node;
    }
}

test "current divider" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit();

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode();

    const v1: FloatType = 678.666;
    const r1: FloatType = 320.001;
    const r2: FloatType = 800.0;

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

    const r2_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .resistor = r2 },
        "R2",
        &.{ vs_plus_id, gnd_id },
    );

    var res = try netlist.analyse(&.{ v1_comp_idx, r1_comp_idx, r2_comp_idx }, 0);
    defer res.deinit(netlist.allocator);

    // currents
    const total_current = v1 * (1 / r1 + 1 / r2);
    const current1 = v1 / r1;
    const current2 = v1 / r2;
    try checkCurrentDC(&res, r1_comp_idx, current1);
    try checkCurrentDC(&res, r2_comp_idx, current2);
    try checkCurrentDC(&res, v1_comp_idx, total_current);

    // voltages
    try checkVoltageDC(&res, gnd_id, 0);
    try checkVoltageDC(&res, vs_plus_id, v1);
}

test "current divider many" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit();

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode();

    const v1: FloatType = 678.666;

    const v1_comp_idx = try netlist.addComponent(
        component.Component.Inner{ .voltage_source = v1 },
        "V1",
        &.{ vs_plus_id, gnd_id },
    );

    const r_list = [_]FloatType{
        4.1,
        6.8,
        9.45,
        123.45,
        300.555,
        10987.00123,
        0.005,
    };
    var r_comp_idxs: [r_list.len]usize = undefined;
    inline for (r_list, 0..) |resistance, i| {
        r_comp_idxs[i] = try netlist.addComponent(
            .{ .resistor = resistance },
            std.fmt.comptimePrint("R{}", .{i + 1}),
            &.{ vs_plus_id, gnd_id },
        );
    }

    const currents_watched = .{v1_comp_idx} ++ r_comp_idxs;
    var res = try netlist.analyse(&currents_watched, 0);
    defer res.deinit(netlist.allocator);

    comptime var total_resistance: FloatType = 0;
    comptime for (r_list) |r| {
        total_resistance += 1 / r;
    };

    // currents
    const total_current = v1 * total_resistance;
    for (r_list, 0..) |r, i| {
        try checkCurrentDC(&res, v1_comp_idx, total_current);
        const current = v1 / r;
        try checkCurrentDC(&res, r_comp_idxs[i], current);
    }

    // voltages
    try checkVoltageDC(&res, gnd_id, 0);
    try checkVoltageDC(&res, vs_plus_id, v1);
}
