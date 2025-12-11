const std = @import("std");
const bland = @import("bland");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");
const dvui = @import("dvui");
const GraphicComponent = @import("../component.zig").GraphicComponent;
const VectorRenderer = @import("../VectorRenderer.zig");

const Component = component.Component;
const GridPosition = circuit.GridPosition;
const Rotation = circuit.Rotation;
const Float = bland.Float;

const vs_module = bland.component.voltage_source_module;

var voltage_source_counter: usize = 0;

pub fn setNewComponentName(buff: []u8) ![]u8 {
    voltage_source_counter += 1;
    return std.fmt.bufPrint(buff, "V{}", .{voltage_source_counter});
}

pub fn getTerminals(
    pos: GridPosition,
    rotation: Rotation,
    terminals: []GridPosition,
) []GridPosition {
    return common.twoTerminalTerminals(pos, rotation, terminals);
}

pub fn getOccupiedGridPositions(
    pos: GridPosition,
    rotation: Rotation,
    occupied: []component.OccupiedGridPosition,
) []component.OccupiedGridPosition {
    return common.twoTerminalOccupiedPoints(pos, rotation, occupied);
}

pub fn centerForMouse(pos: GridPosition, rotation: Rotation) GridPosition {
    return common.twoTerminalCenterForMouse(pos, rotation);
}

pub fn renderPropertyBox(
    voltage_output: *bland.component.source.OutputFunction,
    value_buffer: *GraphicComponent.ValueBuffer,
    selected_component_changed: bool,
) void {
    const entries = [_][]const u8{ "DC", "Phasor", "Sine", "Square" };
    const radio_group = dvui.radioGroup(@src(), .{}, .{ .label = .{ .text = "Function" } });
    defer radio_group.deinit();

    var function_changed: bool = false;

    for (0..entries.len) |i| {
        const active = i == @intFromEnum(value_buffer.voltage_source.selected_function);

        if (dvui.radio(@src(), active, entries[i], renderer.radioGroupOpts.override(.{ .id_extra = i }))) {
            value_buffer.voltage_source.selected_function = @enumFromInt(i);
            function_changed = true;
        }
    }

    const changed = function_changed or selected_component_changed;

    switch (value_buffer.voltage_source.selected_function) {
        .dc => {
            if (function_changed) {
                const val = bland.units.parseWithoutUnitSymbol(
                    value_buffer.voltage_source.dc_actual,
                ) catch 5;
                voltage_output.* = .{ .dc = val };
            }

            _ = renderer.textEntrySI(
                @src(),
                "offset",
                &value_buffer.voltage_source.dc_actual,
                .voltage,
                &voltage_output.dc,
                changed,
                .{},
            );
        },
        .phasor => {
            if (function_changed) {
                const amplitude = bland.units.parseWithoutUnitSymbol(
                    value_buffer.voltage_source.phasor_amplitude_actual,
                ) catch 5;
                const phase = bland.units.parseWithoutUnitSymbol(
                    value_buffer.voltage_source.phasor_phase_actual,
                ) catch 0;
                voltage_output.* = .{
                    .phasor = .{
                        .amplitude = amplitude,
                        .phase = phase,
                    },
                };
            }

            _ = renderer.textEntrySI(
                @src(),
                "amplitude",
                &value_buffer.voltage_source.phasor_amplitude_actual,
                .voltage,
                &voltage_output.phasor.amplitude,
                changed,
                .{},
            );

            _ = renderer.textEntrySI(
                @src(),
                "phase",
                &value_buffer.voltage_source.phasor_phase_actual,
                .radian,
                &voltage_output.phasor.phase,
                changed,
                .{},
            );
        },
        .sin => {
            if (function_changed) {
                const amplitude = bland.units.parseWithoutUnitSymbol(
                    value_buffer.voltage_source.sin_amplitude_actual,
                ) catch 5;
                const frequency = bland.units.parseWithoutUnitSymbol(
                    value_buffer.voltage_source.sin_frequency_actual,
                ) catch 10;
                const phase = bland.units.parseWithoutUnitSymbol(
                    value_buffer.voltage_source.sin_phase_actual,
                ) catch 0;

                voltage_output.* = .{
                    .sin = .{
                        .amplitude = amplitude,
                        .phase = phase,
                        .frequency = frequency,
                    },
                };
            }

            _ = renderer.textEntrySI(
                @src(),
                "amplitude",
                &value_buffer.voltage_source.sin_amplitude_actual,
                .voltage,
                &voltage_output.sin.amplitude,
                changed,
                .{},
            );

            _ = renderer.textEntrySI(
                @src(),
                "frequency",
                &value_buffer.voltage_source.sin_frequency_actual,
                .frequency,
                &voltage_output.sin.frequency,
                changed,
                .{},
            );

            _ = renderer.textEntrySI(
                @src(),
                "phase",
                &value_buffer.voltage_source.sin_phase_actual,
                .radian,
                &voltage_output.sin.phase,
                changed,
                .{},
            );
        },
        .square => {
            if (function_changed) {
                const amplitude = bland.units.parseWithoutUnitSymbol(
                    value_buffer.voltage_source.square_amplitude_actual,
                ) catch 5;
                const frequency = bland.units.parseWithoutUnitSymbol(
                    value_buffer.voltage_source.square_frequency_actual,
                ) catch 10;

                voltage_output.* = .{
                    .square = .{
                        .amplitude = amplitude,
                        .frequency = frequency,
                    },
                };
            }

            _ = renderer.textEntrySI(
                @src(),
                "amplitude",
                &value_buffer.voltage_source.square_amplitude_actual,
                .voltage,
                &voltage_output.square.amplitude,
                changed,
                .{},
            );

            _ = renderer.textEntrySI(
                @src(),
                "frequency",
                &value_buffer.voltage_source.square_frequency_actual,
                .frequency,
                &voltage_output.square.frequency,
                changed,
                .{},
            );
        },
    }
}

const total_width = 2.0;
const radius = 0.4;
const wire_len_per_side = (total_width - 2.0 * radius) / 2.0;
const line_len = 0.15;

pub const clickable_shape: GraphicComponent.ClickableShape = .{
    .circle = .{
        .x = wire_len_per_side + radius,
        .y = 0,
        .radius = radius,
    },
};

pub const bodyInstructions: []const VectorRenderer.BrushInstruction = &.{
    // circle
    .{ .reset = {} },
    .{ .arc = .{
        .center = .{
            .x = wire_len_per_side + radius,
            .y = 0,
        },
        .radius = radius,
        .start_angle = 0,
        .sweep_angle = 2.0 * std.math.pi,
    } },
    .{ .stroke = .{ .base_thickness = 1 } },
    // plus
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .place = .{ .x = wire_len_per_side + radius / 2.0 - line_len / 2.0, .y = 0 } },
    .{ .move_rel = .{ .x = line_len, .y = 0 } },
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .place = .{ .x = wire_len_per_side + radius / 2.0, .y = -line_len / 2.0 } },
    .{ .move_rel = .{ .x = 0, .y = line_len } },
    .{ .stroke = .{ .base_thickness = 1 } },
    // minus
    .{ .place = .{ .x = wire_len_per_side + radius + radius / 2.0, .y = -line_len / 2.0 } },
    .{ .move_rel = .{ .x = 0, .y = line_len } },
    .{ .stroke = .{ .base_thickness = 1 } },
};

pub const terminalWireBrushInstructions: []const VectorRenderer.BrushInstruction = &.{
    .{ .snap_pixel_set = true },
    .{ .move_rel = .{ .x = wire_len_per_side, .y = 0 } },
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .place = .{ .x = wire_len_per_side + 2.0 * radius, .y = 0 } },
    .{ .move_rel = .{ .x = wire_len_per_side, .y = 0 } },
    .{ .stroke = .{ .base_thickness = 1 } },
};
