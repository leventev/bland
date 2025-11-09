const std = @import("std");
const bland = @import("bland");

const global = @import("global.zig");
const component = @import("component.zig");
const circuit = @import("circuit.zig");
const sidebar = @import("sidebar.zig");
const circuit_widget = @import("circuit_widget.zig");
const NetList = bland.NetList;

const dvui = @import("dvui");
const GridPosition = circuit.GridPosition;

pub var dark_mode: bool = true;

pub fn renderCenteredText(pos: dvui.Point.Physical, color: dvui.Color, text: []const u8) void {
    const f = dvui.Font{
        .id = .fromName(global.font_name),
        .size = global.circuit_font_size,
    };

    const s = dvui.Font.textSize(f, text);

    const r = dvui.Rect.Physical{
        .x = pos.x - s.w / 2,
        .y = pos.y - s.h / 2,
        .w = s.w,
        .h = s.h,
    };

    dvui.renderText(.{
        .color = color,
        .background_color = null,
        .debug = false,
        .font = f,
        .rs = .{
            .r = r,
        },
        .text = text,
    }) catch @panic("failed to render text");
}

pub fn drawRect(rect: dvui.Rect.Physical, color: dvui.Color, thickness: f32) void {
    dvui.Rect.stroke(rect, dvui.Rect.Physical.all(0), .{
        .color = color,
        .thickness = thickness,
    });
}

pub fn fillRect(rect: dvui.Rect.Physical, color: dvui.Color) void {
    dvui.Rect.fill(rect, dvui.Rect.Physical.all(0), .{
        .color = color,
    });
}

pub fn drawLine(p1: dvui.Point.Physical, p2: dvui.Point.Physical, color: dvui.Color, thickness: f32) void {
    dvui.Path.stroke(
        .{ .points = &.{ p1, p2 } },
        .{ .color = color, .thickness = thickness },
    );
}

pub const ComponentRenderType = enum {
    normal,
    holding,
    unable_to_place,
    hovered,
    selected,

    pub fn colors(self: ComponentRenderType) ComponentRenderColors {
        switch (self) {
            .normal => return .{
                .wire_color = dvuiColorFromHex(0x32f032ff),
                .component_color = dvuiColorFromHex(0xb428e6ff),
            },
            .holding => return .{
                .wire_color = dvuiColorFromHex(0x999999ff),
                .component_color = dvuiColorFromHex(0x999999ff),
            },
            .unable_to_place => return .{
                .wire_color = dvuiColorFromHex(0xbb4040ff),
                .component_color = dvuiColorFromHex(0xbb4040ff),
            },
            .hovered => return .{
                .wire_color = dvuiColorFromHex(0x32f032ff),
                .component_color = dvuiColorFromHex(0x44ffffff),
            },
            .selected => return .{
                .wire_color = dvuiColorFromHex(0x32f032ff),
                .component_color = dvuiColorFromHex(0xff4444ff),
            },
        }
    }

    pub fn thickness(self: ComponentRenderType) f32 {
        return switch (self) {
            .normal, .hovered => 1,
            .holding, .selected, .unable_to_place => 4,
        };
    }
};

const ComponentRenderColors = struct {
    wire_color: dvui.Color,
    component_color: dvui.Color,
};

fn dvuiColorFromHex(color: u32) dvui.Color {
    return dvui.Color{
        .r = @intCast(color >> 24),
        .g = @intCast((color >> 16) & 0xFF),
        .b = @intCast((color >> 8) & 0xFF),
        .a = @intCast(color & 0xFF),
    };
}

pub const TerminalWire = struct {
    pos: dvui.Point,
    pixel_length: f32,
    direction: circuit.Wire.Direction,
};

pub fn renderTerminalWire(
    wire: TerminalWire,
    render_type: ComponentRenderType,
) void {
    const pos = wire.pos;
    const wire_color = render_type.colors().wire_color;
    const thickness = render_type.thickness();

    switch (wire.direction) {
        .horizontal => {
            drawLine(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y - 1,
                },
                dvui.Point.Physical{
                    .x = pos.x + wire.pixel_length,
                    .y = pos.y - 1,
                },
                wire_color,
                thickness,
            );

            drawLine(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y,
                },
                dvui.Point.Physical{
                    .x = pos.x + wire.pixel_length,
                    .y = pos.y,
                },
                wire_color,
                thickness,
            );
        },
        .vertical => {
            drawLine(
                dvui.Point.Physical{
                    .x = pos.x - 1,
                    .y = pos.y,
                },
                dvui.Point.Physical{
                    .x = pos.x - 1,
                    .y = pos.y + wire.pixel_length,
                },
                wire_color,
                thickness,
            );

            drawLine(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y,
                },
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + wire.pixel_length,
                },
                wire_color,
                thickness,
            );
        },
    }
}

fn renderTerminalWires(
    wires: []TerminalWire,
    render_type: ComponentRenderType,
) void {
    for (wires) |wire| {
        renderTerminalWire(wire, render_type);
    }
}

pub fn renderWire(
    circuit_rect: dvui.Rect.Physical,
    wire: circuit.Wire,
    render_type: ComponentRenderType,
) void {
    const pos = wire.pos.toCircuitPosition(circuit_rect);
    const length: f32 = @floatFromInt(wire.length * global.grid_size);

    const wire_color = render_type.colors().wire_color;
    const thickness = render_type.thickness();

    if (render_type == .holding) {
        const rect1 = dvui.Rect.Physical{
            .x = pos.x - 3,
            .y = pos.y - 3,
            .w = 6,
            .h = 6,
        };
        drawRect(rect1, wire_color, thickness);

        const pos2 = wire.end().toCircuitPosition(circuit_rect);

        const rect2 = dvui.Rect.Physical{
            .x = pos2.x - 3,
            .y = pos2.y - 3,
            .w = 6,
            .h = 6,
        };
        drawRect(rect2, wire_color, thickness);
    }

    switch (wire.direction) {
        .horizontal => {
            drawLine(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y - 1,
                },
                dvui.Point.Physical{
                    .x = pos.x + length,
                    .y = pos.y - 1,
                },
                wire_color,
                thickness,
            );
            drawLine(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y,
                },
                dvui.Point.Physical{
                    .x = pos.x + length,
                    .y = pos.y,
                },
                wire_color,
                thickness,
            );
        },
        .vertical => {
            drawLine(
                dvui.Point.Physical{
                    .x = pos.x - 1,
                    .y = pos.y,
                },
                dvui.Point.Physical{
                    .x = pos.x - 1,
                    .y = pos.y + length,
                },
                wire_color,
                thickness,
            );
            drawLine(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y,
                },
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + length,
                },
                wire_color,
                thickness,
            );
        },
    }
}

fn renderToolbox() bool {
    var toolbox = dvui.box(@src(), .{
        .dir = .vertical,
    }, .{
        .expand = .horizontal,
        .background = true,
        .style = .window,
    });
    defer toolbox.deinit();

    var menu = dvui.menu(@src(), .horizontal, .{});
    defer menu.deinit();

    if (dvui.menuItemLabel(@src(), "File", .{ .submenu = true }, .{ .tag = "first-focusable" })) |r| {
        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        if (dvui.menuItemLabel(@src(), "Quit", .{}, .{ .expand = .horizontal }) != null) {
            return false;
        }
    }

    if (dvui.menuItemLabel(@src(), "Components", .{ .submenu = true }, .{})) |r| {
        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        if (dvui.menuItemLabel(@src(), "Rotate held component", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_rotation = circuit.placement_rotation.rotateClockwise();
            fw.close();
        }

        if (dvui.menuItemLabel(@src(), "Resistor", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .component;
            circuit.held_component = .resistor;
            fw.close();
        }

        if (dvui.menuItemLabel(@src(), "Voltage source", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .component;
            circuit.held_component = .voltage_source;
            fw.close();
        }

        if (dvui.menuItemLabel(@src(), "Current source", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .component;
            circuit.held_component = .current_source;
            fw.close();
        }

        if (dvui.menuItemLabel(@src(), "Ground", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .component;
            circuit.held_component = .ground;
            fw.close();
        }

        if (dvui.menuItemLabel(@src(), "Capacitor", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .component;
            circuit.held_component = .capacitor;
            fw.close();
        }

        if (dvui.menuItemLabel(@src(), "Inductor", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .component;
            circuit.held_component = .inductor;
            fw.close();
        }

        if (dvui.menuItemLabel(@src(), "Current controlled voltage source", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .component;
            circuit.held_component = .ccvs;
            fw.close();
        }

        if (dvui.menuItemLabel(@src(), "Current controlled current source", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .component;
            circuit.held_component = .cccs;
            fw.close();
        }
    }

    if (dvui.menuItemLabel(@src(), "Circuit", .{ .submenu = true }, .{})) |r| {
        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        if (dvui.menuItemLabel(@src(), "Wire", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .wire;
            fw.close();
        }

        if (dvui.menuItemLabel(@src(), "DC Analysis", .{}, .{ .expand = .horizontal }) != null) {
            circuit.main_circuit.analyseDC();
            fw.close();
        }

        if (dvui.menuItemLabel(@src(), "Frequency Sweep Analysis", .{}, .{ .expand = .horizontal }) != null) {
            circuit.main_circuit.analyseFrequencySweep(1, 1e7, 700);
            fw.close();
        }
    }

    if (dvui.menuItemLabel(@src(), "Settings", .{ .submenu = true }, .{})) |r| {
        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        if (dvui.menuItemLabel(@src(), "Toggle light/dark mode", .{}, .{ .expand = .horizontal }) != null) {
            dark_mode = !dark_mode;
            fw.close();
            if (dark_mode)
                dvui.themeSet(global.dark_theme)
            else
                dvui.themeSet(global.light_theme);
        }
    }

    return true;
}

pub fn render(gpa: std.mem.Allocator) !bool {
    if (!renderToolbox())
        return false;

    var paned = dvui.paned(
        @src(),
        .{
            .collapsed_size = 200,
            .direction = .horizontal,
        },
        .{
            .expand = .both,
            .background = true,
            .color_fill = dvui.themeGet().color(.content, .fill),
        },
    );
    defer paned.deinit();

    if (dvui.firstFrame(paned.data().id)) {
        paned.split_ratio.* = 0.2;
    }

    if (paned.showSecond()) {
        var paned2 = dvui.paned(@src(), .{ .collapsed_size = 200, .direction = .vertical }, .{
            .expand = .both,
            .background = true,
            .color_fill = dvui.themeGet().color(.content, .fill),
        });
        defer paned2.deinit();

        if (paned2.showFirst()) {
            try circuit_widget.renderCircuit(gpa);
        }

        if (paned2.showSecond()) {
            try renderAnalysisResults(gpa);
        }
    }

    if (paned.showFirst()) {
        sidebar.render();
    }

    return true;
}

pub fn renderDCReport(gpa: std.mem.Allocator, dc_report: NetList.DCAnalysisReport) !void {
    const S = struct {
        var scroll_info: dvui.ScrollInfo = .{ .vertical = .given, .horizontal = .none };
        var last_col_width: f32 = 0;
        var resize_cols = false;
    };

    var grid = dvui.grid(@src(), .numCols(2), .{
        .scroll_opts = .{
            .scroll_info = &S.scroll_info,
        },
        .resize_cols = S.resize_cols,
    }, .{
        .expand = .both,
        .background = true,
    });
    defer grid.deinit();
    S.resize_cols = false;

    const DCVariable = struct {
        display_name: []const u8,
        value: bland.Float,
    };

    // TODO: less allocation
    var values = try std.ArrayList(DCVariable).initCapacity(
        gpa,
        dc_report.currents.len + dc_report.voltages.len,
    );
    defer {
        for (values.items) |val| {
            gpa.free(val.display_name);
        }
        defer values.deinit(gpa);
    }

    for (dc_report.voltages, 0..) |voltage, i| {
        try values.append(gpa, .{
            .display_name = try std.fmt.allocPrint(gpa, "V(n{})", .{i}),
            .value = voltage,
        });
    }

    for (dc_report.currents, 0..) |current, i| {
        if (current) |cur| {
            const graphic_comp = circuit.main_circuit.graphic_components.items[i];
            if (graphic_comp.comp.device == .ground) continue;

            const comp_name = graphic_comp.comp.name;
            try values.append(gpa, .{
                .display_name = try std.fmt.allocPrint(gpa, "I({s})", .{comp_name}),
                .value = cur,
            });
        }
    }

    const col_width = (grid.data().contentRect().w - dvui.GridWidget.scrollbar_padding_defaults.w) / 2.0;
    if (col_width < S.last_col_width) {
        S.resize_cols = true;
    }
    S.last_col_width = col_width;

    const scroller = dvui.GridWidget.VirtualScroller.init(grid, .{
        .total_rows = values.items.len,
        .scroll_info = &S.scroll_info,
    });

    const CellStyle = dvui.GridWidget.CellStyle;
    var highlight_hovered: CellStyle.HoveredRow = .{
        .cell_opts = .{
            .background = true,
            .color_fill_hover = dvui.themeGet().color(.highlight, .fill),
            .size = .{ .w = col_width },
        },
    };
    highlight_hovered.processEvents(grid);

    const borders: CellStyle.Borders = .initBox(2, values.items.len, 0, 1);

    const cell_style: CellStyle.Combine(CellStyle.HoveredRow, CellStyle.Borders) = .{
        .style1 = highlight_hovered,
        .style2 = borders,
    };

    dvui.gridHeading(@src(), grid, 0, "Variable", .fixed, dvui.GridWidget.CellStyle{
        .cell_opts = .{
            .size = .{ .w = col_width },
        },
    });
    dvui.gridHeading(@src(), grid, 1, "Value", .fixed, dvui.GridWidget.CellStyle{
        .cell_opts = .{
            .size = .{ .w = col_width },
        },
    });

    const first = scroller.startRow();
    const last = scroller.endRow();

    for (first..last) |n| {
        const val = values.items[n];
        var cell_num = dvui.GridWidget.Cell.colRow(0, n);

        {
            var cell = grid.bodyCell(@src(), cell_num, cell_style.cellOptions(cell_num));
            defer cell.deinit();

            dvui.label(@src(), "{s}", .{val.display_name}, .{});
        }
        cell_num.col_num += 1;
        {
            var cell = grid.bodyCell(@src(), cell_num, cell_style.cellOptions(cell_num));
            defer cell.deinit();

            dvui.label(@src(), "{d:.5}", .{val.value}, .{});
        }
    }
}

pub fn renderFWReport(gpa: std.mem.Allocator, fw_report: NetList.FrequencySweepReport) !void {
    // TODO: reset min, max on fw_rep change

    const S = struct {
        var xaxis: dvui.PlotWidget.Axis = .{
            .name = "Frequency (Hz)",
            .scale = .{ .log = .{ .base = 10 } },
            .ticks = .{
                .format = .{
                    .custom = formatFrequency,
                },
                .locations = .{
                    .auto = .{
                        .num_ticks = 8,
                    },
                },
            },
        };

        var yaxis: dvui.PlotWidget.Axis = .{
            .name = "Amplitude (dB)",
            .ticks = .{
                .locations = .{
                    .auto = .{
                        .num_ticks = 8,
                    },
                },
            },
        };

        var var_choice: usize = 1;
        var prev_var_choice: usize = 1;
    };

    const node_count = fw_report.nodeCount();
    const component_count = fw_report.componentCount();

    // TODO: allocate less or use arena or something else
    var var_entries = try gpa.alloc([]u8, node_count + component_count);
    defer gpa.free(var_entries);
    for (0..node_count) |i| {
        var_entries[i] = try std.fmt.allocPrint(gpa, "Voltage #{}", .{i});
    }
    for (0..component_count) |i| {
        var_entries[node_count + i] = try std.fmt.allocPrint(gpa, "Current #{}", .{i});
    }
    defer {
        for (var_entries) |ent| {
            gpa.free(ent);
        }
    }

    _ = dvui.dropdown(@src(), var_entries, &S.var_choice, .{});

    if (S.prev_var_choice != S.var_choice) {
        S.xaxis.min = null;
        S.xaxis.max = null;
        S.yaxis.min = null;
        S.yaxis.max = null;
        S.prev_var_choice = S.var_choice;
    }

    var plot = dvui.plot(@src(), .{
        .title = var_entries[S.var_choice],
        .x_axis = &S.xaxis,
        .y_axis = &S.yaxis,
        .border_thick = 1.0,
        .mouse_hover = true,
    }, .{ .expand = .both });
    defer plot.deinit();

    var s1 = plot.line();
    defer s1.deinit();

    if (S.var_choice >= node_count) {
        const comp_idx = S.var_choice - node_count;
        const current = fw_report.current(comp_idx);
        for (current, 0..) |c, i| {
            if (c) |c_val| {
                const freq = fw_report.frequency_values[i];
                const value = 20 * @log10(c_val.magnitude());
                s1.point(freq, value);
            }
        }
    } else {
        const voltage = fw_report.voltage(S.var_choice);
        for (voltage, 0..) |v, i| {
            const freq = fw_report.frequency_values[i];
            const value = 20 * @log10(v.magnitude());
            s1.point(freq, value);
        }
    }

    s1.stroke(2, dvui.themeGet().focus);
}

pub fn renderAnalysisResults(gpa: std.mem.Allocator) !void {
    var vbox = dvui.box(
        @src(),
        .{},
        .{
            .min_size_content = .{ .w = 300, .h = 100 },
            .expand = .both,
            .padding = dvui.Rect.all(8),
            .background = true,
            .border = dvui.Rect{ .y = 2 },
        },
    );
    defer vbox.deinit();

    if (circuit.analysis_results.items.len == 0) return;

    // TODO: allocate less or use arena or something else
    var fw_entries = try gpa.alloc([]u8, circuit.analysis_results.items.len);
    defer gpa.free(fw_entries);
    for (circuit.analysis_results.items, 0..) |res, i| {
        fw_entries[i] = switch (res) {
            .dc => |_| try std.fmt.allocPrint(gpa, "Analysis #{} (DC)", .{i}),
            .frequency_sweep => |_| try std.fmt.allocPrint(gpa, "Analysis #{} (Freq sweep)", .{i}),
        };
    }
    defer {
        for (fw_entries) |ent| {
            gpa.free(ent);
        }
    }

    const S = struct {
        var fw_choice: usize = 0;
    };

    _ = dvui.dropdown(@src(), fw_entries, &S.fw_choice, .{});

    var report_box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .border = dvui.Rect{ .y = 2 },
        .color_border = .gray,
        .expand = .both,
        .background = true,
    });
    defer report_box.deinit();

    const chosen = circuit.analysis_results.items[S.fw_choice];
    switch (chosen) {
        .dc => |dc_rep| try renderDCReport(gpa, dc_rep),
        .frequency_sweep => |fw_rep| try renderFWReport(gpa, fw_rep),
    }
}

fn formatFrequency(gpa: std.mem.Allocator, freq: f64) ![]const u8 {
    if (freq < 1000) {
        return try std.fmt.allocPrint(gpa, "{d:.2} Hz", .{freq});
    } else if (freq < 1e6) {
        return try std.fmt.allocPrint(gpa, "{d:.2} kHz", .{freq / 1e3});
    } else if (freq < 1e9) {
        return try std.fmt.allocPrint(gpa, "{d:.2} MHz", .{freq / 1e6});
    } else if (freq < 1e12) {
        return try std.fmt.allocPrint(gpa, "{d:.2} GHz", .{freq / 1e9});
    } else unreachable;
}
