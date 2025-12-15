const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");
const source = @import("source.zig");
const NetList = @import("../NetList.zig");
const validator = @import("../validator.zig");

const OutputFunction = source.OutputFunction;
const Component = component.Component;
const Float = bland.Float;
const Complex = bland.Complex;
const StampOptions = Component.Device.StampOptions;
const StampError = Component.Device.StampError;

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .current_source = .{ .dc = 1 } };
}

pub fn stampMatrix(
    current_output: OutputFunction,
    terminal_node_ids: []const NetList.Node.Id,
    mna: *MNA,
    aux_idx_counter: usize,
    stamp_opts: StampOptions,
) StampError!void {
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    const RealOrComplex = union(enum) {
        real: Float,
        complex: Complex,
    };

    // TODO: explain stamping
    const current: RealOrComplex = switch (stamp_opts) {
        .dc => blk: {
            switch (current_output) {
                .dc => |dc_val| break :blk RealOrComplex{ .real = dc_val },
                else => return error.InvalidOutputFunctionForAnalysisMode,
            }
        },
        .transient => |trans| blk: {
            // TODO: validate sin params(frequency)
            switch (current_output) {
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
            switch (current_output) {
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

    const aux_eq_idx = aux_idx_counter;
    mna.stampVoltageCurrent(v_plus, aux_eq_idx, 1);
    mna.stampVoltageCurrent(v_minus, aux_eq_idx, -1);
    mna.stampCurrentCurrent(aux_eq_idx, aux_eq_idx, 1);

    switch (current) {
        .real => |c| mna.stampCurrentRHS(aux_eq_idx, c),
        .complex => |c| mna.stampCurrentRHSComplex(aux_eq_idx, c),
    }
}

pub fn validate(
    output_function: OutputFunction,
    _: *const NetList,
    terminal_node_ids: []const NetList.Node.Id,
) validator.ComponentValidationResult {
    const value_invalid = switch (output_function) {
        .dc, .phasor => false,
        .sin => |sin_data| sin_data.frequency <= 0,
        .square => |square_data| square_data.frequency <= 0,
    };

    return validator.ComponentValidationResult{
        .value_invalid = value_invalid,
        .shorted = terminal_node_ids[0] == terminal_node_ids[1],
    };
}
