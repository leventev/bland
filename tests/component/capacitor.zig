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

test "RC series low-pass sinusoidal steady state" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode(gpa);
    const c_plus_id = try netlist.allocateNode(gpa);

    const v1_amplitude: Float = 76.4;
    const v1_phase: Float = 27 / 180 * std.math.pi;
    const r1: Float = 2000;
    const c1: Float = 34.5e-7;

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
        &.{ vs_plus_id, c_plus_id },
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
        &.{ v1_comp_idx, r1_comp_idx, c1_comp_idx },
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

        const cap_voltage = v1.mul(Complex.reciprocal(
            Complex.init(1, 2 * std.math.pi * freq * r1 * c1),
        ));

        // voltages
        try checkVoltageAC(&ac_report, gnd_id, Complex.init(0, 0));
        try checkVoltageAC(&ac_report, vs_plus_id, v1);
        try checkVoltageAC(&ac_report, c_plus_id, cap_voltage);

        // currents
        const current = v1.sub(cap_voltage).div(Complex.init(r1, 0));
        try checkCurrentAC(&ac_report, v1_comp_idx, current.neg());
        try checkCurrentAC(&ac_report, r1_comp_idx, current);
        try checkCurrentAC(&ac_report, c1_comp_idx, current);
    }
}

test "RC series high-pass sinusoidal steady state" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode(gpa);
    const r_plus_id = try netlist.allocateNode(gpa);

    const v1_amplitude: Float = 358.3333;
    const v1_phase: Float = 234 / 180 * std.math.pi;
    const r1: Float = 17691;
    const c1: Float = 640e-6;

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
        &.{ r_plus_id, gnd_id },
    );

    const c1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .capacitor = c1 },
        "C1",
        &.{ vs_plus_id, r_plus_id },
    );

    const start_freq = 1;
    const end_freq = 1e8;
    const freq_count = 800;

    var res = try netlist.analyseFrequencySweep(
        gpa,
        start_freq,
        end_freq,
        freq_count,
        &.{ v1_comp_idx, r1_comp_idx, c1_comp_idx },
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

        const resistor_voltage = v1.mul(Complex.div(
            Complex.init(0, 2 * std.math.pi * freq * r1 * c1),
            Complex.init(1, 2 * std.math.pi * freq * r1 * c1),
        ));

        // voltages
        try checkVoltageAC(&ac_report, gnd_id, Complex.init(0, 0));
        try checkVoltageAC(&ac_report, vs_plus_id, v1);
        try checkVoltageAC(&ac_report, r_plus_id, resistor_voltage);

        // currents
        const current = resistor_voltage.div(Complex.init(r1, 0));
        try checkCurrentAC(&ac_report, v1_comp_idx, current.neg());
        try checkCurrentAC(&ac_report, r1_comp_idx, current);
        try checkCurrentAC(&ac_report, c1_comp_idx, current);
    }
}

test "RC series low-pass complex sinusoidal steady state" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode(gpa);
    const c1_plus_id = try netlist.allocateNode(gpa);
    const c234_plus_id = try netlist.allocateNode(gpa);

    const v1_amplitude: Float = 150;
    const v1_phase: Float = -45 / 180 * std.math.pi;
    const r1: Float = 42.111;
    const c1: Float = 483e-9;
    const c2: Float = 500e-6;
    const c3: Float = 300e-9;
    const c4: Float = 20e-6;

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
        &.{ vs_plus_id, c1_plus_id },
    );

    const c1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .capacitor = c1 },
        "C1",
        &.{ c1_plus_id, c234_plus_id },
    );

    const c2_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .capacitor = c2 },
        "C2",
        &.{ c234_plus_id, gnd_id },
    );

    const c3_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .capacitor = c3 },
        "C3",
        &.{ c234_plus_id, gnd_id },
    );

    const c4_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .capacitor = c4 },
        "C4",
        &.{ c234_plus_id, gnd_id },
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
            c1_comp_idx,
            c2_comp_idx,
            c3_comp_idx,
            c4_comp_idx,
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

        const c1_impedance = Complex.init(0, -1 / (ang_freq * c1));
        const c234_impedance = Complex.init(0, -1 / (ang_freq * c2)).reciprocal().add(
            Complex.init(0, -1 / (ang_freq * c3)).reciprocal().add(
                Complex.init(0, -1 / (ang_freq * c4)).reciprocal(),
            ),
        ).reciprocal();

        const total_impedance = Complex.init(r1, 0).add(c1_impedance).add(c234_impedance);

        const c1_voltage = v1.mul(Complex.div(
            c1_impedance,
            total_impedance,
        ));

        const c234_voltage = v1.mul(Complex.div(
            c234_impedance,
            total_impedance,
        ));

        // voltages
        try checkVoltageAC(&ac_report, gnd_id, Complex.init(0, 0));
        try checkVoltageAC(&ac_report, vs_plus_id, v1);
        try checkVoltage2AC(&ac_report, c1_plus_id, c234_plus_id, c1_voltage);
        try checkVoltageAC(&ac_report, c234_plus_id, c234_voltage);

        // currents
        const current = v1.div(total_impedance);
        try checkCurrentAC(&ac_report, v1_comp_idx, current.neg());
        try checkCurrentAC(&ac_report, r1_comp_idx, current);
        try checkCurrentAC(&ac_report, c1_comp_idx, current);
    }
}

test "RC series high-pass complex sinusoidal steady state" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode(gpa);
    const c234_plus_id = try netlist.allocateNode(gpa);
    const r1_plus_id = try netlist.allocateNode(gpa);

    const v1_amplitude: Float = 600;
    const v1_phase: Float = 0 / 180 * std.math.pi;
    const r1: Float = 9;
    const c1: Float = 555e-9;
    const c2: Float = 814e-6;
    const c3: Float = 314e-9;
    const c4: Float = 900e-6;

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
        &.{ r1_plus_id, gnd_id },
    );

    const c1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .capacitor = c1 },
        "C1",
        &.{ vs_plus_id, c234_plus_id },
    );

    const c2_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .capacitor = c2 },
        "C2",
        &.{ c234_plus_id, r1_plus_id },
    );

    const c3_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .capacitor = c3 },
        "C3",
        &.{ c234_plus_id, r1_plus_id },
    );

    const c4_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .capacitor = c4 },
        "C4",
        &.{ c234_plus_id, r1_plus_id },
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
            c1_comp_idx,
            c2_comp_idx,
            c3_comp_idx,
            c4_comp_idx,
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

        const c1_impedance = Complex.init(0, -1 / (ang_freq * c1));
        const c234_impedance = Complex.init(0, -1 / (ang_freq * c2)).reciprocal().add(
            Complex.init(0, -1 / (ang_freq * c3)).reciprocal().add(
                Complex.init(0, -1 / (ang_freq * c4)).reciprocal(),
            ),
        ).reciprocal();

        const total_impedance = Complex.init(r1, 0).add(c1_impedance).add(c234_impedance);

        const c234_voltage = v1.mul(Complex.div(
            c234_impedance,
            total_impedance,
        ));

        const r1_voltage = v1.mul(Complex.div(
            Complex.init(r1, 0),
            total_impedance,
        ));

        // voltages
        try checkVoltageAC(&ac_report, gnd_id, Complex.init(0, 0));
        try checkVoltageAC(&ac_report, vs_plus_id, v1);
        try checkVoltage2AC(&ac_report, c234_plus_id, r1_plus_id, c234_voltage);
        try checkVoltageAC(&ac_report, r1_plus_id, r1_voltage);

        // currents
        const current = v1.div(total_impedance);
        try checkCurrentAC(&ac_report, v1_comp_idx, current.neg());
        try checkCurrentAC(&ac_report, r1_comp_idx, current);
        try checkCurrentAC(&ac_report, c1_comp_idx, current);
    }
}

test "RC parallel sinusoidal steady state" {
    const gpa = std.testing.allocator;
    var netlist = try NetList.init(gpa);
    defer netlist.deinit(gpa);

    const gnd_id: usize = NetList.ground_node_id;
    const vs_plus_id = try netlist.allocateNode(gpa);

    const v1_amplitude: Float = 100;
    const v1_phase: Float = 78.3 / 180.0 * std.math.pi;
    const r1: Float = 800;
    const c1: Float = 600e-6;

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

    const c1_comp_idx = try netlist.addComponent(
        gpa,
        Component.Device{ .capacitor = c1 },
        "C1",
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
        &.{ v1_comp_idx, r1_comp_idx, c1_comp_idx },
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

        // voltages
        try checkVoltageAC(&ac_report, gnd_id, Complex.init(0, 0));
        try checkVoltageAC(&ac_report, vs_plus_id, v1);

        // currents
        const r1_impedance = Complex.init(r1, 0);
        const c1_impedance = Complex.init(0, -1 / (2 * std.math.pi * freq * c1));

        const total_impedance = r1_impedance.mul(c1_impedance).div(
            r1_impedance.add(c1_impedance),
        );

        const total_current = v1.div(total_impedance);
        const resistor_current = total_current.mul(total_impedance.div(r1_impedance));
        const capacitor_current = total_current.mul(total_impedance.div(c1_impedance));

        try checkCurrentAC(&ac_report, v1_comp_idx, total_current.neg());
        try checkCurrentAC(&ac_report, r1_comp_idx, resistor_current);
        try checkCurrentAC(&ac_report, c1_comp_idx, capacitor_current);
    }
}
