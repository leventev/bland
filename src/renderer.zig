const std = @import("std");
const bland = @import("bland");
const dvui = @import("dvui");

const global = @import("global.zig");
const component = @import("component.zig");
const circuit = @import("circuit.zig");
const sidebar = @import("sidebar.zig");
const circuit_widget = @import("circuit_widget.zig");
const console = @import("console.zig");
const VectorRenderer = @import("VectorRenderer.zig");
const svg = @import("svg.zig");

const NetList = bland.NetList;
const GridPosition = circuit.GridPosition;

pub var dark_mode: bool = true;

pub const ElementRenderType = enum {
    normal,
    holding,
    unable_to_place,
    hovered,
    selected,

    pub fn colors(self: ElementRenderType) ElementRenderColors {
        const normal_wire_color = dvui.Color.fromHSLuv(109, 46.2, 51.2, 100);
        const hovered_wire_color = normal_wire_color.lighten(15);

        const normal_component_color = dvui.Color.fromHSLuv(250, 73.1, 52.1, 100);
        const hovered_component_color = normal_component_color.lighten(15);
        const unable_to_place_color = dvui.Color.fromHSLuv(0, 60, 40, 100);
        const holding_color = dvui.Color.fromHSLuv(200, 5, 50, 100);

        switch (self) {
            .normal => return .{
                .terminal_wire_color = normal_wire_color,
                .component_color = normal_component_color,
                .wire_color = normal_wire_color,
            },
            .holding => return .{
                .terminal_wire_color = holding_color,
                .component_color = holding_color,
                .wire_color = holding_color,
            },
            .unable_to_place => return .{
                .terminal_wire_color = unable_to_place_color,
                .component_color = unable_to_place_color,
                .wire_color = unable_to_place_color,
            },
            .hovered => return .{
                .terminal_wire_color = normal_wire_color,
                .component_color = hovered_component_color,
                .wire_color = hovered_wire_color,
            },
            .selected => return .{
                .terminal_wire_color = normal_wire_color,
                .component_color = hovered_component_color,
                .wire_color = hovered_wire_color,
            },
        }
    }

    pub fn thickness(self: ElementRenderType) f32 {
        return switch (self) {
            .normal, .hovered => 1,
            .holding, .selected, .unable_to_place => 4,
        };
    }

    pub fn wireThickness(self: ElementRenderType) f32 {
        return switch (self) {
            .normal, .hovered => 1,
            .selected => 4,
            .holding, .unable_to_place => 4,
        };
    }
};

const ElementRenderColors = struct {
    component_color: dvui.Color,
    terminal_wire_color: dvui.Color,
    wire_color: dvui.Color,
};

pub const TerminalWire = struct {
    pos: dvui.Point,
    pixel_length: f32,
    direction: circuit.Wire.Direction,
};

fn renderToolbox(parentSubwindowId: dvui.Id) bool {
    var toolbox = dvui.box(@src(), .{
        .dir = .vertical,
    }, .{
        .expand = .horizontal,
        .background = true,
        .style = .window,
    });
    defer toolbox.deinit();

    // TODO: passing parentSubwindowId doesnt seem to work? (after closing the menu
    // the toolbox is still focused)
    // maybe im just stupid, regardless if i get this to work later
    // the dvui.focusWidget call at the end of the function shall be removed
    var menu = dvui.widgetAlloc(dvui.MenuWidget);
    menu.init(@src(), .{
        .dir = .horizontal,
        .parentSubwindowId = parentSubwindowId,
    }, .{});
    menu.data().was_allocated_on_widget_stack = true;
    defer menu.deinit();

    var close = false;

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

        if (dvui.menuItemLabel(@src(), "Rotate held element", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_rotation = circuit.placement_rotation.rotateClockwise();
            fw.close();
            close = true;
        }

        if (dvui.menuItemLabel(@src(), "Resistor", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .{ .new_component = .{ .device_type = .resistor } };
            fw.close();
            close = true;
        }

        if (dvui.menuItemLabel(@src(), "Voltage source", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .{ .new_component = .{ .device_type = .voltage_source } };
            fw.close();
            close = true;
        }

        if (dvui.menuItemLabel(@src(), "Current source", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .{ .new_component = .{ .device_type = .current_source } };
            fw.close();
            close = true;
        }

        if (dvui.menuItemLabel(@src(), "Ground", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .{ .new_ground = {} };
            fw.close();
            close = true;
        }

        if (dvui.menuItemLabel(@src(), "Capacitor", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .{ .new_component = .{ .device_type = .capacitor } };
            fw.close();
            close = true;
        }

        if (dvui.menuItemLabel(@src(), "Inductor", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .{ .new_component = .{ .device_type = .inductor } };
            fw.close();
            close = true;
        }

        if (dvui.menuItemLabel(@src(), "Current controlled voltage source", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .{ .new_component = .{ .device_type = .ccvs } };
            fw.close();
            close = true;
        }

        if (dvui.menuItemLabel(@src(), "Current controlled current source", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .{ .new_component = .{ .device_type = .cccs } };
            fw.close();
            close = true;
        }

        if (dvui.menuItemLabel(@src(), "Diode", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .{ .new_component = .{ .device_type = .diode } };
            fw.close();
            close = true;
        }
    }

    if (dvui.menuItemLabel(@src(), "Circuit", .{ .submenu = true }, .{})) |r| {
        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        if (dvui.menuItemLabel(@src(), "Wire", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .{ .new_wire = .{ .held_wire_p1 = null } };
            fw.close();
            close = true;
        }

        if (dvui.menuItemLabel(@src(), "Pin", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .{ .new_pin = {} };
            fw.close();
            close = true;
        }

        if (dvui.menuItemLabel(@src(), "Export to SVG", .{}, .{ .expand = .horizontal }) != null) {
            svg.exportToSVG(&circuit.main_circuit) catch |err| {
                std.log.err("Failed to export to SVG: {t}", .{err});
            };
            fw.close();
            close = true;
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
            close = true;
        }
    }

    if (close) {
        dvui.focusWidget(null, parentSubwindowId, null);
    }

    return true;
}

pub fn render(gpa: std.mem.Allocator) !bool {
    const subwindowId = dvui.subwindowCurrentId();
    if (!renderToolbox(subwindowId))
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
            var res_console_paned = dvui.paned(@src(), .{
                .collapsed_size = 200,
                .direction = .vertical,
            }, .{
                .expand = .both,
                .background = true,
                .color_fill = dvui.themeGet().color(.content, .fill),
            });
            defer res_console_paned.deinit();

            if (res_console_paned.showFirst()) {
                try renderAnalysisResults(gpa);
            }

            if (res_console_paned.showSecond()) {
                console.renderConsole();
            }
        }
    }

    if (paned.showFirst()) {
        sidebar.render();
    }

    return true;
}

pub fn renderDCReport(
    gpa: std.mem.Allocator,
    report: circuit.AnalysisReport,
    report_changed: bool,
) !void {
    _ = report_changed;
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
        value: []const u8,
    };

    var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    const arena = arena_alloc.allocator();
    defer arena_alloc.deinit();

    const voltages = report.result.dc.voltages;
    const currents = report.result.dc.currents;

    // TODO: less allocations?
    var values = try std.ArrayList(DCVariable).initCapacity(
        gpa,
        currents.len + voltages.len,
    );

    for (report.pinned_nodes) |pinned_node| {
        const voltage = voltages[@intFromEnum(pinned_node.node_id)];
        try values.append(gpa, .{
            .display_name = try std.fmt.allocPrint(arena, "V({s})", .{pinned_node.name}),
            .value = try bland.units.formatUnitAlloc(arena, .voltage, voltage, 3),
        });
    }

    for (currents, 0..) |current, i| {
        if (current) |cur| {
            const comp_name = report.component_names[i];
            if (comp_name) |name| {
                try values.append(gpa, .{
                    .display_name = try std.fmt.allocPrint(arena, "I({s})", .{name}),
                    .value = try bland.units.formatUnitAlloc(arena, .current, cur, 3),
                });
            }
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

            dvui.label(@src(), "{s}", .{val.value}, .{});
        }
    }
}

pub fn renderFWReport(
    gpa: std.mem.Allocator,
    report: circuit.AnalysisReport,
    report_changed: bool,
) !void {
    const S = struct {
        var xaxis: dvui.PlotWidget.Axis = .{
            .name = "Angular frequency (rad/s)",
            .scale = .{ .log = .{ .base = 10 } },
            .ticks = .{
                .format = .{
                    .custom = formatFrequency,
                },
                .locations = .{
                    .auto = .{
                        .tick_num_suggestion = 10,
                    },
                },
                .subticks = true,
            },
        };

        var yaxis: dvui.PlotWidget.Axis = .{
            .name = "Amplitude (dB)",
            .ticks = .{
                .locations = .{
                    .auto = .{
                        .tick_num_suggestion = 10,
                    },
                },
            },
        };

        var var_choice: usize = 0;
        var prev_var_choice: usize = 0;
    };

    S.xaxis.gridline_color = dvui.themeGet().color(.control, .fill).lighten(20);
    S.yaxis.gridline_color = dvui.themeGet().color(.control, .fill).lighten(20);
    S.xaxis.subtick_gridline_color = dvui.themeGet().color(.control, .fill);

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var comp_idxs = try arena.alloc(usize, report.component_names.len);

    var component_entry_count: usize = 0;
    for (report.component_names, 0..) |name, comp_idx| {
        if (name != null) {
            comp_idxs[component_entry_count] = comp_idx;
            component_entry_count += 1;
        }
    }

    // TODO: allocate less or use arena or something else
    var var_entries = try arena.alloc([]u8, report.pinned_nodes.len + component_entry_count);

    for (report.pinned_nodes, 0..) |pin, i| {
        var_entries[i] = try std.fmt.allocPrint(arena, "V({s})", .{pin.name});
    }

    var idx: usize = report.pinned_nodes.len;
    for (report.component_names) |name| {
        if (name) |str| {
            var_entries[idx] = try std.fmt.allocPrint(arena, "I({s})", .{str});
            idx += 1;
        }
    }

    if (report_changed) {
        S.var_choice = 0;
    }

    _ = dvui.dropdown(@src(), var_entries, &S.var_choice, .{});

    if (S.prev_var_choice != S.var_choice or report_changed) {
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

    const fw_result = report.result.frequency_sweep;

    if (S.var_choice >= report.pinned_nodes.len) {
        const comp_entry_idx = S.var_choice - report.pinned_nodes.len;
        const comp_idx: bland.Component.Id = @enumFromInt(comp_idxs[comp_entry_idx]);
        const current = fw_result.current(comp_idx) catch @panic("TODO");
        for (current, 0..) |c, i| {
            if (c) |c_val| {
                const freq = fw_result.frequency_values[i];
                const angular_freq = freq * 2 * std.math.pi;
                const value = 20 * @log10(c_val.magnitude());
                s1.point(angular_freq, value);
            }
        }
    } else {
        const node_id = report.pinned_nodes[S.var_choice].node_id;
        const voltage = fw_result.voltage(node_id) catch @panic("TODO");
        for (voltage, 0..) |v, i| {
            const freq = fw_result.frequency_values[i];
            const angular_freq = freq * 2 * std.math.pi;
            const value = 20 * @log10(v.magnitude());
            s1.point(angular_freq, value);
        }
    }

    s1.stroke(2, dvui.themeGet().focus);
}

pub fn renderTransientReport(
    gpa: std.mem.Allocator,
    report: circuit.AnalysisReport,
    report_changed: bool,
) !void {
    const S = struct {
        var xaxis: dvui.PlotWidget.Axis = .{
            .name = "Time",
            .ticks = .{
                .format = .{
                    .custom = formatTime,
                },
                .locations = .{
                    .auto = .{
                        .tick_num_suggestion = 10,
                    },
                },
            },
        };

        var yaxis: dvui.PlotWidget.Axis = .{
            .name = "Value",
            .ticks = .{
                .locations = .{
                    .auto = .{
                        .tick_num_suggestion = 10,
                    },
                },
            },
        };

        var var_choice: usize = 0;
        var prev_var_choice: usize = 0;
    };

    S.xaxis.gridline_color = dvui.themeGet().color(.control, .fill).lighten(20);
    S.yaxis.gridline_color = dvui.themeGet().color(.control, .fill).lighten(20);

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var comp_idxs = try arena.alloc(usize, report.component_names.len);

    var component_entry_count: usize = 0;
    for (report.component_names, 0..) |name, comp_idx| {
        if (name != null) {
            comp_idxs[component_entry_count] = comp_idx;
            component_entry_count += 1;
        }
    }

    var var_entries = try arena.alloc([]u8, report.pinned_nodes.len + component_entry_count);

    for (0.., report.pinned_nodes) |i, pinned_node| {
        var_entries[i] = try std.fmt.allocPrint(arena, "V({s})", .{pinned_node.name});
    }

    var idx: usize = report.pinned_nodes.len;
    for (report.component_names) |name| {
        if (name) |str| {
            var_entries[idx] = try std.fmt.allocPrint(arena, "I({s})", .{str});
            idx += 1;
        }
    }

    if (report_changed) {
        S.var_choice = 0;
    }

    _ = dvui.dropdown(@src(), var_entries, &S.var_choice, .{});

    if (S.prev_var_choice != S.var_choice or report_changed) {
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

    const trans_result = report.result.transient;

    if (S.var_choice >= report.pinned_nodes.len) {
        const comp_entry_idx = S.var_choice - report.pinned_nodes.len;
        const comp_idx: bland.Component.Id = @enumFromInt(comp_idxs[comp_entry_idx]);
        const current = trans_result.current(comp_idx) catch @panic("TODO");
        for (current, 0..) |c, i| {
            if (c) |c_val| {
                const time = trans_result.time_values[i];
                s1.point(time, c_val);
            }
        }
    } else {
        const node_id = report.pinned_nodes[S.var_choice].node_id;
        const voltage = trans_result.voltage(node_id) catch @panic("TODO");
        for (voltage, 0..) |v, i| {
            const time = trans_result.time_values[i];
            s1.point(time, v);
        }
    }

    s1.stroke(2, dvui.themeGet().focus);
}

pub var analysis_report_choice: usize = 0;
pub var prev_analysis_report_choice: usize = 0;

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

    if (circuit.analysis_reports.items.len == 0) return;

    // TODO: allocate less or use arena or something else
    var result_entries = try gpa.alloc([]u8, circuit.analysis_reports.items.len);
    defer gpa.free(result_entries);
    for (circuit.analysis_reports.items, 0..) |res, i| {
        result_entries[i] = switch (res.result) {
            .dc => |_| try std.fmt.allocPrint(gpa, "Analysis #{} (dc)", .{i}),
            .frequency_sweep => |_| try std.fmt.allocPrint(gpa, "Analysis #{} (freq. sweep)", .{i}),
            .transient => |_| try std.fmt.allocPrint(gpa, "Analysis #{} (transient)", .{i}),
        };
    }
    defer {
        for (result_entries) |ent| {
            gpa.free(ent);
        }
    }

    _ = dvui.dropdown(@src(), result_entries, &analysis_report_choice, .{});

    const changed = prev_analysis_report_choice != analysis_report_choice;
    prev_analysis_report_choice = analysis_report_choice;

    var report_box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .border = dvui.Rect{ .y = 2 },
        .color_border = .gray,
        .expand = .both,
        .background = true,
    });
    defer report_box.deinit();

    const chosen = circuit.analysis_reports.items[analysis_report_choice];
    switch (chosen.result) {
        .dc => try renderDCReport(gpa, chosen, changed),
        .frequency_sweep => try renderFWReport(gpa, chosen, changed),
        .transient => try renderTransientReport(gpa, chosen, changed),
    }
}

fn formatFrequency(gpa: std.mem.Allocator, freq: f64) ![]const u8 {
    return bland.units.formatPrefixAlloc(gpa, freq, 1);
}

fn formatTime(gpa: std.mem.Allocator, time: f64) ![]const u8 {
    return bland.units.formatUnitAlloc(gpa, .time, time, 2);
}

pub const radioGroupOpts = dvui.Options{
    .padding = dvui.Rect.all(3),
};

pub const textEntryLabelOpts = dvui.Options{
    .expand = .horizontal,
    .padding = dvui.Rect.all(2),
    .margin = dvui.Rect{
        .x = 4,
    },
};

pub const textEntryOpts = dvui.Options{
    .expand = .horizontal,
    .margin = dvui.Rect.all(4),
    .padding = dvui.Rect.all(4),
    .border = dvui.Rect{ .h = 2 },
    .corner_radius = dvui.Rect.all(0),
};

pub fn textEntrySI(
    location: std.builtin.SourceLocation,
    comptime label_str: []const u8,
    buff_actual: *[]u8,
    unit: bland.units.Unit,
    val: *bland.Float,
    change: bool,
    opts: dvui.Options,
) bool {
    _ = opts;
    var box = dvui.box(location, .{
        .dir = .vertical,
    }, .{
        .expand = .horizontal,
    });
    defer box.deinit();

    // TODO: styling
    dvui.label(@src(), label_str, .{}, textEntryLabelOpts);

    var box2 = dvui.box(@src(), .{
        .dir = .horizontal,
    }, .{
        .expand = .horizontal,
    });
    defer box2.deinit();

    const prev_val = val.*;
    var changed = false;

    {
        var te = dvui.widgetAlloc(dvui.TextEntryWidget);
        te.init(
            location,
            .{
                .text = .{
                    .internal = .{
                        .limit = 64,
                    },
                },
            },
            textEntryOpts,
        );
        defer te.deinit();

        if (change) {
            te.textSet(buff_actual.*, false);
        }

        te.processEvents();
        te.draw();

        const text = te.getText();
        const parsed = bland.units.parseWithoutUnitSymbol(text);

        if (parsed) |num| {
            // TODO: DO THIS NOT LIKE THIS
            const txt = te.getText();
            buff_actual.len = txt.len;
            @memcpy(buff_actual.*, txt);
            val.* = num;
            changed = val.* != prev_val;
        } else |err| {
            switch (err) {
                error.InvalidNumber => {},
                error.InvalidPrefix => {},
            }
            const rs = te.data().borderRectScale();
            rs.r.outsetAll(1).stroke(
                te.data().options.corner_radiusGet().scale(rs.s, dvui.Rect.Physical),
                .{
                    .thickness = 3 * rs.s,
                    .color = dvui.themeGet().err.fill orelse .red,
                    .after = true,
                },
            );
        }
    }

    dvui.label(@src(), "{s}", .{unit.symbol()}, .{
        .color_text = dvui.themeGet().color(.content, .text),
        .font = dvui.themeGet().font_title,
        .margin = dvui.Rect.all(4),
        .padding = dvui.Rect.all(4),
        .gravity_y = 0.5,
    });

    return false;
}

pub fn renderWire(
    vector_renderer: *const VectorRenderer,
    wire: circuit.Wire,
    render_type: ElementRenderType,
    junctions: ?*const std.AutoHashMapUnmanaged(GridPosition, circuit.GraphicCircuit.Junction),
) !void {
    const instructions: []const VectorRenderer.BrushInstruction = &.{
        .{ .snap_pixel_set = true },
        .{ .move_rel = .{ .x = 1, .y = 0 } },
        .{ .stroke = .{ .base_thickness = 1 } },
    };

    var scale: f32 = @floatFromInt(wire.length);
    var x: f32 = @floatFromInt(wire.pos.x);
    var y: f32 = @floatFromInt(wire.pos.y);
    if (junctions) |js| {
        const start_circle_rendered = if (js.get(wire.pos)) |junction|
            junction.kind() != .none
        else
            false;

        const end_circle_rendered = if (js.get(wire.end())) |junction|
            junction.kind() != .none
        else
            false;

        const sign: f32 = @floatFromInt(std.math.sign(wire.length));

        if (start_circle_rendered) {
            scale -= sign * circuit.GraphicCircuit.junction_radius;
            switch (wire.direction) {
                .horizontal => x += sign * circuit.GraphicCircuit.junction_radius,
                .vertical => y += sign * circuit.GraphicCircuit.junction_radius,
            }
        }
        if (end_circle_rendered) {
            scale -= sign * circuit.GraphicCircuit.junction_radius;
        }
    }

    const colors = render_type.colors();
    const thickness = render_type.wireThickness();
    const rotation: f32 = if (wire.direction == .vertical) std.math.pi / 2.0 else 0.0;
    try vector_renderer.render(
        instructions,
        .{
            .translate = .{
                .x = x,
                .y = y,
            },
            .scale = .both(scale),
            .line_scale = thickness * circuit_widget.zoom_scale,
            .rotate = rotation,
        },
        .{ .stroke_color = colors.wire_color },
    );
}

pub fn renderPin(
    vector_renderer: *const VectorRenderer,
    grid_pos: circuit.GridPosition,
    rotation: circuit.Rotation,
    label: []const u8,
    render_type: ElementRenderType,
) !void {
    // TODO: better font handling
    const f = dvui.Font{
        .id = .fromName(global.font_name),
        .size = global.circuit_font_size * circuit_widget.zoom_scale,
    };

    const angle: f32 = 15.0 / 180.0 * std.math.pi;

    const color = render_type.colors().component_color;
    const thickness = render_type.thickness();

    const label_size = dvui.Font.textSize(f, label);
    const grid_size = VectorRenderer.grid_cell_px_size * circuit_widget.zoom_scale;
    const grid_pos_f = VectorRenderer.Vector{
        .x = @floatFromInt(grid_pos.x),
        .y = @floatFromInt(grid_pos.y),
    };

    const padding = 0.2;
    const rect_width = label_size.w / grid_size + padding;
    const rect_height = label_size.h / grid_size + padding;
    const gap: f32 = 0.2;

    const triangle_head: []const VectorRenderer.BrushInstruction = &.{
        .{ .place = .{ .x = 1, .y = -1 } },
        .{ .move_rel = .{ .x = -1, .y = 1 } },
        .{ .move_rel = .{ .x = 1, .y = 1 } },
        .{ .stroke = .{ .base_thickness = 1 } },
    };

    const partial_rect: []const VectorRenderer.BrushInstruction = &.{
        .{ .place = .{ .x = 0, .y = -0.5 } },
        .{ .move_rel = .{ .x = 1, .y = 0 } },
        .{ .move_rel = .{ .x = 0, .y = 1 } },
        .{ .move_rel = .{ .x = -1, .y = 0 } },
        .{ .stroke = .{ .base_thickness = 1 } },
    };

    switch (rotation) {
        .left, .right => {
            const inv = rotation == .left;
            const rot: f32 = if (inv) std.math.pi else 0;
            const triangle_len = (rect_height / 2) * std.math.atan(angle);

            try vector_renderer.render(
                triangle_head,
                .{
                    .translate = .{
                        .x = grid_pos_f.x + if (inv) -gap else gap,
                        .y = grid_pos_f.y,
                    },
                    .line_scale = thickness,
                    .scale = .{
                        .x = triangle_len,
                        .y = rect_height / 2,
                    },
                    .rotate = rot,
                },
                .{ .stroke_color = color },
            );

            const x_rect_start = gap + triangle_len;
            const x_rect_off = if (inv) -x_rect_start else x_rect_start;
            try vector_renderer.render(
                partial_rect,
                .{
                    .translate = .{
                        .x = x_rect_off + grid_pos_f.x,
                        .y = grid_pos_f.y,
                    },
                    .line_scale = thickness,
                    .scale = .{
                        .x = rect_width,
                        .y = rect_height,
                    },
                    .rotate = rot,
                },
                .{ .stroke_color = color },
            );

            const x_off: f32 = (if (inv) -rect_width else 0) + padding / 2.0;
            try vector_renderer.renderText(.{
                .x = grid_pos_f.x + x_rect_off + x_off,
                .y = grid_pos_f.y - (label_size.h / 2) / grid_size,
            }, label, dvui.themeGet().color(.content, .text), null);
        },
        .top, .bottom => {
            const inv = rotation == .top;
            const rot: f32 = if (inv) -std.math.pi / 2.0 else std.math.pi / 2.0;
            const triangle_len = (rect_width / 2) * std.math.atan(angle);

            try vector_renderer.render(
                triangle_head,
                .{
                    .translate = .{
                        .x = grid_pos_f.x,
                        .y = grid_pos_f.y + if (inv) -gap else gap,
                    },
                    .line_scale = thickness,
                    .scale = .{
                        .x = triangle_len,
                        .y = rect_width / 2,
                    },
                    .rotate = rot,
                },
                .{ .stroke_color = color },
            );

            const y_rect_start = gap + triangle_len;
            const y_rect_off = if (inv) -y_rect_start else y_rect_start;
            try vector_renderer.render(
                partial_rect,
                .{
                    .translate = .{
                        .x = grid_pos_f.x,
                        .y = grid_pos_f.y + y_rect_off,
                    },
                    .line_scale = thickness,
                    .scale = .{
                        .x = rect_height,
                        .y = rect_width,
                    },
                    .rotate = rot,
                },
                .{ .stroke_color = color },
            );

            const y_off: f32 = if (inv)
                -y_rect_start - rect_height / 2 - label_size.h / grid_size / 2.0
            else
                y_rect_start + rect_height / 2 - label_size.h / grid_size / 2.0;

            try vector_renderer.renderText(.{
                .x = grid_pos_f.x - rect_width / 2 + padding / 2.0,
                .y = grid_pos_f.y + y_off,
            }, label, dvui.themeGet().color(.content, .text), null);
        },
    }
}
