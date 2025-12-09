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

var inductor_counter: usize = 0;

pub fn setNewComponentName(buff: []u8) ![]u8 {
    inductor_counter += 1;
    return std.fmt.bufPrint(buff, "L{}", .{inductor_counter});
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

const wire_pixel_len = 22;
const middle_len = 2 * global.grid_size - 2 * wire_pixel_len;
const circles = 3;
const circle_diameter = 2 * (global.grid_size - wire_pixel_len) / circles;

pub fn render(
    circuit_rect: dvui.Rect.Physical,
    grid_pos: GridPosition,
    rot: Rotation,
    name: ?[]const u8,
    value: ?GraphicComponent.ValueBuffer,
    render_type: renderer.ElementRenderType,
) void {
    const pos = grid_pos.toCircuitPosition(circuit_rect);

    const inductor_color = render_type.colors().component_color;
    const thickness = render_type.thickness();

    var buff: [256]u8 = undefined;
    const value_str = if (value) |val|
        std.fmt.bufPrint(&buff, "{s}{s}", .{
            val.inductor.actual,
            bland.units.Unit.inductance.symbol(),
        }) catch unreachable
    else
        null;

    switch (rot) {
        .left, .right => {
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = pos,
                .direction = .horizontal,
                .pixel_length = wire_pixel_len,
            }, render_type);
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = dvui.Point{
                    .x = pos.x + global.grid_size * 2,
                    .y = pos.y,
                },
                .direction = .horizontal,
                .pixel_length = -wire_pixel_len,
            }, render_type);

            var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());
            defer path.deinit();

            for (0..circles) |i| {
                const j = circles - (i + 1);
                const offset: f32 = @as(f32, @floatFromInt(j * circle_diameter + circle_diameter / 2));
                path.addArc(
                    dvui.Point.Physical{
                        .x = pos.x + wire_pixel_len + offset,
                        .y = pos.y,
                    },
                    circle_diameter / 2,
                    2 * dvui.math.pi,
                    dvui.math.pi,
                    false,
                );
            }

            path.build().stroke(.{
                .color = inductor_color,
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
        },
        .bottom, .top => {
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = pos,
                .direction = .vertical,
                .pixel_length = wire_pixel_len,
            }, render_type);
            renderer.renderTerminalWire(renderer.TerminalWire{
                .pos = dvui.Point{
                    .x = pos.x,
                    .y = pos.y + global.grid_size * 2,
                },
                .direction = .vertical,
                .pixel_length = -wire_pixel_len,
            }, render_type);

            var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());
            defer path.deinit();

            for (0..circles) |i| {
                const j = circles - (i + 1);
                const offset: f32 = @as(f32, @floatFromInt(j * circle_diameter + circle_diameter / 2));
                path.addArc(
                    dvui.Point.Physical{
                        .x = pos.x,
                        .y = pos.y + wire_pixel_len + offset,
                    },
                    circle_diameter / 2,
                    dvui.math.pi / 2.0,
                    -dvui.math.pi / 2.0,
                    false,
                );
            }

            path.build().stroke(.{
                .color = inductor_color,
                .thickness = thickness,
            });

            if (name) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + global.grid_size / 2,
                        .y = pos.y + global.grid_size - (global.circuit_font_size / 2 + 8),
                    },
                    dvui.themeGet().color(.content, .text),
                    str,
                );
            }

            if (value_str) |str| {
                renderer.renderCenteredText(
                    dvui.Point.Physical{
                        .x = pos.x + global.grid_size / 2,
                        .y = pos.y + global.grid_size + (global.circuit_font_size / 2 + 8),
                    },
                    dvui.themeGet().color(.content, .text),
                    str,
                );
            }
        },
    }
}

pub fn renderPropertyBox(
    l: *Float,
    value_buffer: *GraphicComponent.ValueBuffer,
    selected_component_changed: bool,
) void {
    _ = renderer.textEntrySI(
        @src(),
        "inductance",
        &value_buffer.inductor.actual,
        .inductance,
        l,
        selected_component_changed,
        .{},
    );
}

pub fn mouseInside(
    grid_pos: GridPosition,
    rotation: Rotation,
    circuit_rect: dvui.Rect.Physical,
    mouse_pos: dvui.Point.Physical,
) bool {
    const pos = grid_pos.toCircuitPosition(circuit_rect);

    const tolerance = 3;

    const rect: dvui.Rect.Physical = switch (rotation) {
        .left, .right => dvui.Rect.Physical{
            .x = pos.x + wire_pixel_len - tolerance,
            .y = pos.y - circle_diameter / 2 - tolerance,
            .w = middle_len + 2 * tolerance,
            .h = circle_diameter / 2 + 2 * tolerance,
        },
        .bottom, .top => dvui.Rect.Physical{
            .x = pos.x - tolerance,
            .y = pos.y + wire_pixel_len - tolerance,
            .w = circle_diameter / 2 + 2 * tolerance,
            .h = middle_len + 2 * tolerance,
        },
    };

    return rect.contains(mouse_pos);
}

const total_width = 2.0;
const radius = 0.15;
const wire_len_per_side = (total_width - 4 * 2 * radius) / 2.0;

pub const bodyInstructions: []const VectorRenderer.BrushInstruction = &.{
    .{ .reset = {} },
    .{ .arc = .{
        .center = .{ .x = wire_len_per_side + radius, .y = 0 },
        .radius = radius,
        .start_angle = -std.math.pi,
        .sweep_angle = std.math.pi,
    } },
    .{ .arc = .{
        .center = .{ .x = wire_len_per_side + radius + 2.0 * radius, .y = 0 },
        .radius = radius,
        .start_angle = -std.math.pi,
        .sweep_angle = std.math.pi,
    } },
    .{ .arc = .{
        .center = .{ .x = wire_len_per_side + radius + 4.0 * radius, .y = 0 },
        .radius = radius,
        .start_angle = -std.math.pi,
        .sweep_angle = std.math.pi,
    } },
    .{ .arc = .{
        .center = .{ .x = wire_len_per_side + radius + 6.0 * radius, .y = 0 },
        .radius = radius,
        .start_angle = -std.math.pi,
        .sweep_angle = std.math.pi,
    } },
    .{ .stroke = .{ .base_thickness = 1 } },
};

pub const terminalWireBrushInstructions: []const VectorRenderer.BrushInstruction = &.{
    .{ .snap_pixel_set = true },
    .{ .move_rel = .{ .x = wire_len_per_side, .y = 0 } },
    .{ .stroke = .{ .base_thickness = 1 } },
    .{ .place = .{ .x = total_width - wire_len_per_side, .y = 0 } },
    .{ .move_rel = .{ .x = wire_len_per_side, .y = 0 } },
    .{ .stroke = .{ .base_thickness = 1 } },
};
