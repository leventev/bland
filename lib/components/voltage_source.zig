const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");
const source = @import("source.zig");

const OutputFunction = source.OutputFunction;
const Component = component.Component;
const Float = bland.Float;
const Complex = bland.Complex;
const StampOptions = Component.Device.StampOptions;
const StampError = Component.Device.StampError;

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .voltage_source = .{ .dc = 5 } };
}

pub fn formatValue(value: Float, buf: []u8) !?[]const u8 {
    return try bland.units.formatUnitBuf(buf, .voltage, value, 3);
}

pub fn stampMatrix(
    voltage_output: OutputFunction,
    terminal_node_ids: []const usize,
    mna: *MNA,
    current_group_2_idx: ?usize,
    stamp_opts: StampOptions,
) StampError!void {
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];
    const curr_idx = current_group_2_idx orelse @panic("Invalid voltage stamp");

    const RealOrComplex = union(enum) {
        real: Float,
        complex: Complex,
    };

    // TODO: explain stamping
    const voltage: RealOrComplex = switch (stamp_opts) {
        .dc => blk: {
            switch (voltage_output) {
                .dc => |dc_val| break :blk RealOrComplex{ .real = dc_val },
                else => return error.InvalidOutputFunctionForAnalysisMode,
            }
        },
        .transient => |trans| blk: {
            // TODO: validate sin params(frequency)
            switch (voltage_output) {
                .dc => |dc_val| break :blk RealOrComplex{ .real = dc_val },
                .sin => |params| {
                    const ang_freq = 2 * std.math.pi * params.frequency;
                    const arg = ang_freq * trans.time + params.phase;
                    break :blk RealOrComplex{ .real = params.amplitude * @sin(arg) };
                },
                .square => |params| {
                    // TODO: only accept good values
                    const period = 1 / params.frequency;
                    const rem = @rem(trans.time, period);

                    if (rem <= period * 0.5) {
                        break :blk RealOrComplex{ .real = params.amplitude };
                    } else {
                        break :blk RealOrComplex{ .real = -params.amplitude };
                    }
                },
                .phasor => return error.InvalidOutputFunctionForAnalysisMode,
            }
        },
        .sin_steady_state => blk: {
            switch (voltage_output) {
                .phasor => |params| {
                    const re = params.amplitude * @cos(params.phase);
                    const im = params.amplitude * @sin(params.phase);
                    break :blk RealOrComplex{
                        .complex = Complex.init(re, im),
                    };
                },
                else => return error.InvalidOutputFunctionForAnalysisMode,
            }
        },
    };

    mna.stampVoltageCurrent(v_plus, curr_idx, 1);
    mna.stampVoltageCurrent(v_minus, curr_idx, -1);

    mna.stampCurrentVoltage(curr_idx, v_plus, 1);
    mna.stampCurrentVoltage(curr_idx, v_minus, -1);

    switch (voltage) {
        .real => |v| mna.stampCurrentRHS(curr_idx, v),
        .complex => |v| mna.stampCurrentRHSComplex(curr_idx, v),
    }
}
