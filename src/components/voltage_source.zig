const std = @import("std");
const bland = @import("bland");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");
const dvui = @import("dvui");
const GraphicComponent = @import("../component.zig").GraphicComponent;

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

const radius = 25;

pub fn render(
    circuit_rect: dvui.Rect.Physical,
    grid_pos: GridPosition,
    rot: Rotation,
    name: ?[]const u8,
    value: ?GraphicComponent.ValueBuffer,
    render_type: renderer.ComponentRenderType,
) void {
    const pos = grid_pos.toCircuitPosition(circuit_rect);

    const total_len = 2 * global.grid_size;
    const diameter = 2 * radius;
    const wire_len = (total_len - diameter) / 2;

    const render_colors = render_type.colors();
    const thickness = render_type.thickness();

    var buff: [256]u8 = undefined;
    const value_str = if (value) |_|
        std.fmt.bufPrint(&buff, "{s}{s}", .{
            "5",
            bland.units.Unit.voltage.symbol(),
        }) catch unreachable
    else
        null;

    switch (rot) {
        .left, .right => {
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = pos,
                .direction = .horizontal,
                .pixel_length = wire_len,
            }, render_type);
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = dvui.Point{
                    .x = pos.x + global.grid_size * 2,
                    .y = pos.y,
                },
                .direction = .horizontal,
                .pixel_length = -wire_len,
            }, render_type);

            var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());
            defer path.deinit();

            path.addArc(
                dvui.Point.Physical{
                    .x = pos.x + global.grid_size,
                    .y = pos.y,
                },
                diameter / 2,
                dvui.math.pi * 2,
                0,
                false,
            );

            path.build().stroke(.{
                .color = render_colors.component_color,
                .thickness = thickness,
            });

            if (name) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + global.grid_size / 3,
                        .y = pos.y - global.grid_size / 4,
                    },
                    dvui.themeGet().color(.content, .text),
                    str,
                );
            }

            if (value_str) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + 2 * global.grid_size - global.grid_size / 3,
                        .y = pos.y - global.grid_size / 4,
                    },
                    dvui.themeGet().color(.content, .text),
                    str,
                );
            }

            const sign: f32 = if (rot == .right) -1 else 1;
            renderer.renderCenteredText(
                dvui.Point.Physical{
                    .x = pos.x + global.grid_size + sign * diameter / 4,
                    .y = pos.y,
                },
                render_colors.component_color,
                "+",
            );
            renderer.renderCenteredText(
                dvui.Point.Physical{
                    .x = pos.x + global.grid_size - sign * diameter / 4,
                    .y = pos.y,
                },
                render_colors.component_color,
                "-",
            );
        },
        .top, .bottom => {
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = pos,
                .direction = .vertical,
                .pixel_length = wire_len,
            }, render_type);
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = dvui.Point{
                    .x = pos.x,
                    .y = pos.y + global.grid_size * 2,
                },
                .direction = .vertical,
                .pixel_length = -wire_len,
            }, render_type);

            var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());
            defer path.deinit();

            path.addArc(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + global.grid_size,
                },
                diameter / 2,
                dvui.math.pi * 2,
                0,
                false,
            );

            path.build().stroke(.{
                .color = render_colors.component_color,
                .thickness = thickness,
            });

            if (name) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + global.grid_size / 2,
                        .y = pos.y + global.grid_size / 3,
                    },
                    dvui.themeGet().color(.content, .text),
                    str,
                );
            }

            if (value_str) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + global.grid_size / 2,
                        .y = pos.y + 2 * global.grid_size - global.grid_size / 3,
                    },
                    dvui.themeGet().color(.content, .text),
                    str,
                );
            }

            const sign: f32 = if (rot == .bottom) -1 else 1;
            renderer.renderCenteredText(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + global.grid_size + sign * diameter / 4,
                },
                render_colors.component_color,
                "+",
            );
            renderer.renderCenteredText(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + global.grid_size - sign * diameter / 4,
                },
                render_colors.component_color,
                "-",
            );
        },
    }
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

        if (dvui.radio(@src(), active, entries[i], .{ .id_extra = i })) {
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

pub fn mouseInside(
    grid_pos: GridPosition,
    rotation: Rotation,
    circuit_rect: dvui.Rect.Physical,
    mouse_pos: dvui.Point.Physical,
) bool {
    const pos = grid_pos.toCircuitPosition(circuit_rect);

    const center: dvui.Point.Physical = switch (rotation) {
        .left, .right => .{ .x = pos.x + global.grid_size, .y = pos.y },
        .top, .bottom => .{ .x = pos.x, .y = pos.y + global.grid_size },
    };

    const xd = mouse_pos.x - center.x;
    const yd = mouse_pos.y - center.y;

    const check_radius = radius + 3;

    return xd * xd + yd * yd <= check_radius * check_radius;
}
