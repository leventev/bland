const std = @import("std");
const component = @import("../component.zig");
const circuit = @import("../circuit.zig");
const common = @import("common.zig");
const renderer = @import("../renderer.zig");
const global = @import("../global.zig");
const sidebar = @import("../sidebar.zig");

const dvui = @import("dvui");

const Component = component.Component;
const GridPosition = circuit.GridPosition;
const Rotation = circuit.Rotation;

var ccvs_counter: usize = 0;

pub const Inner = struct {
    controller_name_buff: []u8,
    controller_name: []u8,
    coefficient: circuit.FloatType,

    // set by netlist.analyse
    controller_group_2_idx: ?usize,

    pub fn deinit(self: *Inner, allocator: std.mem.Allocator) void {
        allocator.free(self.controller_name_buff);
        self.controller_name_buff = &.{};
        self.controller_name = &.{};
        self.coefficient = 0;
        self.controller_group_2_idx = null;
    }
};

pub fn defaultValue(allocator: std.mem.Allocator) !Component.Inner {
    return Component.Inner{ .ccvs = .{
        .controller_name_buff = try allocator.alloc(u8, component.max_component_name_length),
        .controller_name = &.{},
        .coefficient = 0,
        .controller_group_2_idx = null,
    } };
}

pub fn setNewComponentName(buff: []u8) ![]u8 {
    ccvs_counter += 1;
    return std.fmt.bufPrint(buff, "CCVS{}", .{ccvs_counter});
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

fn formatValue(inner: Inner, buf: []u8) !?[]const u8 {
    return try std.fmt.bufPrint(buf, "{d}{s}", .{
        inner.coefficient,
        inner.controller_name,
    });
}

pub fn render(
    circuit_rect: dvui.Rect.Physical,
    grid_pos: GridPosition,
    rot: Rotation,
    name: ?[]const u8,
    value: ?Inner,
    render_type: renderer.ComponentRenderType,
) void {
    const pos = grid_pos.toCircuitPosition(circuit_rect);

    const total_len = 2 * global.grid_size;
    const middle_len = 50;
    const wire_len = (total_len - middle_len) / 2;

    const diamond_off = middle_len / 2;

    const render_colors = render_type.colors();
    const thickness = render_type.thickness();

    var buff: [256]u8 = undefined;
    const value_str = if (value) |val| formatValue(
        val,
        buff[0..],
    ) catch unreachable else null;

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

            path.addPoint(dvui.Point.Physical{ .x = pos.x + wire_len, .y = pos.y });
            path.addPoint(dvui.Point.Physical{ .x = pos.x + wire_len + diamond_off, .y = pos.y - diamond_off });
            path.addPoint(dvui.Point.Physical{ .x = pos.x + wire_len + 2 * diamond_off, .y = pos.y });
            path.addPoint(dvui.Point.Physical{ .x = pos.x + wire_len + diamond_off, .y = pos.y + diamond_off });
            path.addPoint(dvui.Point.Physical{ .x = pos.x + wire_len, .y = pos.y });

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
                    .x = pos.x + global.grid_size + sign * middle_len / 4,
                    .y = pos.y,
                },
                render_colors.component_color,
                "+",
            );
            renderer.renderCenteredText(
                dvui.Point.Physical{
                    .x = pos.x + global.grid_size - sign * middle_len / 4,
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

            path.addPoint(dvui.Point.Physical{ .x = pos.x, .y = pos.y + wire_len });
            path.addPoint(dvui.Point.Physical{ .x = pos.x - diamond_off, .y = pos.y + wire_len + diamond_off });
            path.addPoint(dvui.Point.Physical{ .x = pos.x, .y = pos.y + wire_len + 2 * diamond_off });
            path.addPoint(dvui.Point.Physical{ .x = pos.x + diamond_off, .y = pos.y + wire_len + diamond_off });
            path.addPoint(dvui.Point.Physical{ .x = pos.x, .y = pos.y + wire_len });

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
                    .y = pos.y + global.grid_size + sign * middle_len / 4,
                },
                render_colors.component_color,
                "+",
            );
            renderer.renderCenteredText(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + global.grid_size - sign * middle_len / 4,
                },
                render_colors.component_color,
                "-",
            );
        },
    }
}

pub fn renderPropertyBox(inner: *Inner) void {
    var box = dvui.box(
        @src(),
        .{ .dir = .vertical },
        .{
            .expand = .vertical,
        },
    );
    defer box.deinit();

    dvui.label(@src(), "coefficient", .{}, .{
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_body,
    });

    _ = dvui.textEntryNumber(@src(), circuit.FloatType, .{
        .value = &inner.coefficient,
    }, .{
        .color_fill = dvui.themeGet().color(.control, .fill),
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_body,
        .expand = .horizontal,
        .margin = dvui.Rect.all(4),
    });

    dvui.label(@src(), "controller name", .{}, .{
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_body,
    });

    var te = dvui.textEntry(@src(), .{
        .text = .{
            .buffer = inner.controller_name_buff,
        },
    }, .{
        .color_fill = dvui.themeGet().color(.control, .fill),
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_body,
        .expand = .horizontal,
        .margin = dvui.Rect.all(4),
    });

    if (dvui.firstFrame(te.data().id) or sidebar.selected_component_changed) {
        te.textSet(inner.controller_name, false);
    }

    inner.controller_name = te.getText();

    te.deinit();
}

pub fn stampMatrix(
    inner: Inner,
    terminal_node_ids: []const usize,
    mna: *circuit.MNA,
    current_group_2_idx: ?usize,
) void {
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];

    const ccvs_curr_idx = current_group_2_idx orelse @panic("Invalid ccvs stamp");
    const controller_curr_idx = inner.controller_group_2_idx orelse @panic("?");

    // TODO: explain stamping
    mna.stampVoltageCurrent(v_plus, ccvs_curr_idx, 1);
    mna.stampVoltageCurrent(v_minus, ccvs_curr_idx, -1);

    mna.stampCurrentVoltage(ccvs_curr_idx, v_plus, 1);
    mna.stampCurrentVoltage(ccvs_curr_idx, v_minus, -1);
    mna.stampCurrentCurrent(
        ccvs_curr_idx,
        controller_curr_idx,
        -inner.coefficient,
    );
}
