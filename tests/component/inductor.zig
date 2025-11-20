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

test "RL series" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode(gpa);
    const l_plus_id = try netlist.allocateNode(gpa);

    const v1_amplitude: Float = 560;
    const v1_phase: Float = 362.4 / 180.0 * std.math.pi;
    const r1: Float = 440.5;
    const l1: Float = 888.888e-6;

    const v1 = Complex.init(
        v1_amplitude * @cos(v1_phase),
        v1_amplitude * @sin(v1_phase),
    );

    const v1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{
            .voltage_source = .{
                .phasor = .{
                    .amplitude = v1_amplitude,
                    .phase = v1_phase,
                },
            },
        },
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
        &.{ l_plus_id, gnd_id },
    );

    const start_freq = 1;
    const end_freq = 1e8;
    const freq_count = 800;

    var res = try netlist.analyseFrequencySweep(
        gpa,
        start_freq,
        end_freq,
        freq_count,
        &.{ v1_comp_idx, r1_comp_idx, l1_comp_idx },
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

        const inductor_voltage = v1.mul(Complex.div(
            Complex.init(0, angular_freq * l1),
            Complex.init(r1, angular_freq * l1),
        ));

        // voltages
        try checkVoltageAC(&ac_report, gnd_id, Complex.init(0, 0));
        try checkVoltageAC(&ac_report, vs_plus_id, v1);
        try checkVoltageAC(&ac_report, l_plus_id, inductor_voltage);

        // currents
        const current = v1.sub(inductor_voltage).div(Complex.init(r1, 0));
        try checkCurrentAC(&ac_report, v1_comp_idx, current.neg());
        try checkCurrentAC(&ac_report, r1_comp_idx, current);
        try checkCurrentAC(&ac_report, l1_comp_idx, current);
    }
}

test "RL parallel" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode(gpa);

    const v1_amplitude: Float = 3.3;
    const v1_phase: Float = 44 / 180 * std.math.pi;
    const r1: Float = 600;
    const l1: Float = 2.7e-3;

    const v1 = Complex.init(
        v1_amplitude * @cos(v1_phase),
        v1_amplitude * @sin(v1_phase),
    );

    const v1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{
            .voltage_source = .{
                .phasor = .{
                    .amplitude = v1_amplitude,
                    .phase = v1_phase,
                },
            },
        },
        "V1",
        &.{ vs_plus_id, gnd_id },
    );

    const r1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .resistor = r1 },
        "R1",
        &.{ vs_plus_id, gnd_id },
    );

    const l1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .inductor = l1 },
        "L1",
        &.{ vs_plus_id, gnd_id },
    );

    const start_freq = 1;
    const end_freq = 1e8;
    const freq_count = 800;

    var res = try netlist.analyseFrequencySweep(
        gpa,
        start_freq,
        end_freq,
        freq_count,
        &.{ v1_comp_idx, r1_comp_idx, l1_comp_idx },
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

        // voltages
        try checkVoltageAC(&ac_report, gnd_id, Complex.init(0, 0));
        try checkVoltageAC(&ac_report, vs_plus_id, v1);

        // currents
        const r1_impedance = Complex.init(r1, 0);
        const l1_impedance = Complex.init(0, angular_freq * l1);

        const total_impedance = r1_impedance.mul(l1_impedance).div(
            r1_impedance.add(l1_impedance),
        );

        const total_current = v1.div(total_impedance);
        const resistor_current = total_current.mul(total_impedance.div(r1_impedance));
        const capacitor_current = total_current.mul(total_impedance.div(l1_impedance));

        try checkCurrentAC(&ac_report, v1_comp_idx, total_current.neg());
        try checkCurrentAC(&ac_report, r1_comp_idx, resistor_current);
        try checkCurrentAC(&ac_report, l1_comp_idx, capacitor_current);
    }
}

test "RL complex" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode(gpa);
    const l1_plus_id = try netlist.allocateNode(gpa);
    const l234_plus_id = try netlist.allocateNode(gpa);

    const v1_amplitude: Float = 990;
    const v1_phase: Float = 777 / 180 * std.math.pi;
    const r1: Float = 60;
    const l1: Float = 983e-6;
    const l2: Float = 200e-3;
    const l3: Float = 440e-6;
    const l4: Float = 20e-3;

    const v1 = Complex.init(
        v1_amplitude * @cos(v1_phase),
        v1_amplitude * @sin(v1_phase),
    );

    const v1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{
            .voltage_source = .{
                .phasor = .{
                    .amplitude = v1_amplitude,
                    .phase = v1_phase,
                },
            },
        },
        "V1",
        &.{ vs_plus_id, gnd_id },
    );

    const r1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .resistor = r1 },
        "R1",
        &.{ vs_plus_id, l1_plus_id },
    );

    const l1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .inductor = l1 },
        "L1",
        &.{ l1_plus_id, l234_plus_id },
    );

    const l2_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .inductor = l2 },
        "L2",
        &.{ l234_plus_id, gnd_id },
    );

    const l3_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .inductor = l3 },
        "L3",
        &.{ l234_plus_id, gnd_id },
    );

    const l4_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .inductor = l4 },
        "L4",
        &.{ l234_plus_id, gnd_id },
    );

    const start_freq = 1;
    const end_freq = 1e8;
    const freq_count = 800;

    var res = try netlist.analyseFrequencySweep(
        gpa,
        start_freq,
        end_freq,
        freq_count,
        &.{
            v1_comp_idx,
            r1_comp_idx,
            l1_comp_idx,
            l2_comp_idx,
            l3_comp_idx,
            l4_comp_idx,
        },
    );
    defer res.deinit(gpa);

    var ac_report = try NetList.ACAnalysisReport.init(
        gpa,
        netlist.nodes.items.len,
        netlist.components.items.len,
    );
    defer ac_report.deinit(gpa);

    for (0.., res.frequency_values) |freq_idx, freq| {
        const ang_freq = 2 * std.math.pi * freq;
        try res.analysisReportForFreq(freq_idx, &ac_report);

        const l1_impedance = Complex.init(0, ang_freq * l1);
        const l234_impedance = Complex.init(0, ang_freq * l2).reciprocal().add(
            Complex.init(0, ang_freq * l3).reciprocal().add(
                Complex.init(0, ang_freq * l4).reciprocal(),
            ),
        ).reciprocal();

        const total_impedance = Complex.init(r1, 0).add(l1_impedance).add(l234_impedance);

        const l1_voltage = v1.mul(Complex.div(
            l1_impedance,
            total_impedance,
        ));

        const l234_voltage = v1.mul(Complex.div(
            l234_impedance,
            total_impedance,
        ));

        // voltages
        try checkVoltageAC(&ac_report, gnd_id, Complex.init(0, 0));
        try checkVoltageAC(&ac_report, vs_plus_id, v1);
        try checkVoltage2AC(&ac_report, l1_plus_id, l234_plus_id, l1_voltage);
        try checkVoltageAC(&ac_report, l234_plus_id, l234_voltage);

        // currents
        const current = v1.div(total_impedance);
        try checkCurrentAC(&ac_report, v1_comp_idx, current.neg());
        try checkCurrentAC(&ac_report, r1_comp_idx, current);
        try checkCurrentAC(&ac_report, l1_comp_idx, current);
    }
}
