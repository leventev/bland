const std = @import("std");
const bland = @import("bland");
const circuit_testing = @import("../circuit_tests.zig");

const Component = bland.Component;
const NetList = bland.NetList;
const Float = bland.Float;
const Complex = bland.Complex;
const checkCurrentDC = circuit_testing.checkCurrentDC;
const checkVoltageDC = circuit_testing.checkVoltageDC;
const checkVoltage2DC = circuit_testing.checkVoltage2DC;

const checkCurrentAC = circuit_testing.checkCurrentAC;
const checkVoltageAC = circuit_testing.checkVoltageAC;
const checkVoltage2AC = circuit_testing.checkVoltage2AC;

test "RLC series" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode(gpa);
    const l_plus_id = try netlist.allocateNode(gpa);
    const c_plus_id = try netlist.allocateNode(gpa);

    const v1: Float = 1500;
    const r1: Float = 200;
    const l1: Float = 457.6e-3;
    const c1: Float = 50e-6;

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
        &.{ vs_plus_id, l_plus_id },
    );

    const l1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .inductor = l1 },
        "L1",
        &.{ l_plus_id, c_plus_id },
    );

    const c1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .capacitor = c1 },
        "C1",
        &.{ c_plus_id, gnd_id },
    );

    const start_freq = 1;
    const end_freq = 1e8;
    const freq_count = 800;

    var res = try netlist.analyseFrequencySweep(
        gpa,
        start_freq,
        end_freq,
        freq_count,
        &.{ v1_comp_idx, r1_comp_idx, l1_comp_idx, c1_comp_idx },
    );
    defer res.deinit(gpa);

    var ac_report = try NetList.ACAnalysisReport.init(
        gpa,
        netlist.nodes.items.len,
        netlist.components.items.len,
    );
    defer ac_report.deinit(gpa);

    for (0.., res.frequency_values) |freq_idx, freq| {
        try res.analysisReportForFreq(freq_idx, &ac_report);

        const angular_freq = 2 * std.math.pi * freq;

        const l_impedance = Complex.init(0, angular_freq * l1);
        const c_impedance = Complex.init(0, -1 / (angular_freq * c1));
        const lc_impedance = l_impedance.add(c_impedance);

        // VS -- R -- L -- C -- GND
        const lc_voltage = Complex.init(v1, 0).mul(Complex.div(
            lc_impedance,
            Complex.init(r1, 0).add(lc_impedance),
        ));

        const c_voltage = Complex.init(v1, 0).mul(Complex.div(
            c_impedance,
            Complex.init(r1, 0).add(lc_impedance),
        ));

        // voltages
        try checkVoltageAC(&ac_report, gnd_id, Complex.init(0, 0));
        try checkVoltageAC(&ac_report, vs_plus_id, Complex.init(v1, 0));
        try checkVoltageAC(&ac_report, l_plus_id, lc_voltage);
        try checkVoltageAC(&ac_report, c_plus_id, c_voltage);

        // currents
        const current = Complex.init(v1, 0).sub(lc_voltage).div(Complex.init(r1, 0));
        try checkCurrentAC(&ac_report, v1_comp_idx, current.neg());
        try checkCurrentAC(&ac_report, r1_comp_idx, current);
        try checkCurrentAC(&ac_report, l1_comp_idx, current);
    }
}

test "RLC parallel" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode(gpa);
    const lc_plus_id = try netlist.allocateNode(gpa);

    const v1: Float = 15;
    const r1: Float = 4.5;
    const l1: Float = 632e-6;
    const c1: Float = 298e-12;

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
        &.{ vs_plus_id, lc_plus_id },
    );

    const l1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .inductor = l1 },
        "L1",
        &.{ lc_plus_id, gnd_id },
    );

    const c1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .capacitor = c1 },
        "C1",
        &.{ lc_plus_id, gnd_id },
    );

    const start_freq = 1;
    const end_freq = 1e8;
    const freq_count = 800;

    var res = try netlist.analyseFrequencySweep(
        gpa,
        start_freq,
        end_freq,
        freq_count,
        &.{ v1_comp_idx, r1_comp_idx, l1_comp_idx, c1_comp_idx },
    );
    defer res.deinit(gpa);

    var ac_report = try NetList.ACAnalysisReport.init(
        gpa,
        netlist.nodes.items.len,
        netlist.components.items.len,
    );
    defer ac_report.deinit(gpa);

    for (0.., res.frequency_values) |freq_idx, freq| {
        try res.analysisReportForFreq(freq_idx, &ac_report);

        const angular_freq = 2 * std.math.pi * freq;

        // VS -- R -- L -- GND
        //        \-- C --/
        const l_impedance = Complex.init(0, angular_freq * l1);
        const c_impedance = Complex.init(0, -1 / (angular_freq * c1));
        const lc_impedance = l_impedance.mul(c_impedance).div(l_impedance.add(c_impedance));

        const lc_voltage = Complex.init(v1, 0).mul(Complex.div(
            lc_impedance,
            Complex.init(r1, 0).add(lc_impedance),
        ));

        // voltages
        try checkVoltageAC(&ac_report, gnd_id, Complex.init(0, 0));
        try checkVoltageAC(&ac_report, vs_plus_id, Complex.init(v1, 0));
        try checkVoltageAC(&ac_report, lc_plus_id, lc_voltage);

        // currents
        const current = Complex.init(v1, 0).sub(lc_voltage).div(Complex.init(r1, 0));

        const c_current = current.mul(lc_impedance.div(c_impedance));
        const l_current = current.mul(lc_impedance.div(l_impedance));

        try checkCurrentAC(&ac_report, v1_comp_idx, current.neg());
        try checkCurrentAC(&ac_report, r1_comp_idx, current);
        try checkCurrentAC(&ac_report, l1_comp_idx, l_current);
        try checkCurrentAC(&ac_report, c1_comp_idx, c_current);
    }
}
