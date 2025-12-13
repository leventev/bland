const std = @import("std");

const global = @import("global.zig");
const component = @import("component.zig");
const circuit = @import("circuit.zig");
const renderer = @import("renderer.zig");

const bland = @import("bland");
const dvui = @import("dvui");

const tl_box_opts = dvui.Options{
    .expand = .horizontal,
    .background = true,
    .border = dvui.Rect{ .h = 1 },
};

const tl_opts = dvui.Options{
    .gravity_x = 0.5,
};

pub fn renderComponentList() void {
    {
        var tl_box = dvui.box(@src(), .{ .dir = .horizontal }, tl_box_opts);
        defer tl_box.deinit();

        var tl = dvui.textLayout(@src(), .{}, tl_opts);
        defer tl.deinit();

        tl.addText("Components", .{});
    }

    var scroll = dvui.scrollArea(
        @src(),
        .{},
        .{
            .expand = .horizontal,
        },
    );
    defer scroll.deinit();

    switch (circuit.placement_mode) {
        .none => |*data| data.hovered_element = null,
        else => {},
    }

    for (0.., circuit.main_circuit.graphic_components.items) |i, graphic_comp| {
        const select_component_id: ?usize = if (circuit.selection) |element| blk: {
            break :blk switch (element) {
                .component => |comp_id| comp_id,
                else => null,
            };
        } else null;

        const style = if (select_component_id == i)
            dvui.Theme.Style.Name.highlight
        else
            dvui.Theme.Style.Name.control;

        const font = if (select_component_id == i)
            dvui.themeGet().font_title_2
        else
            dvui.themeGet().font_body;

        var bw = dvui.widgetAlloc(dvui.ButtonWidget);
        bw.init(@src(), .{}, .{
            .id_extra = i,
            .expand = .horizontal,
            .style = style,
            .margin = dvui.Rect.all(0),
            .padding = dvui.Rect.all(4),
            .corner_radius = dvui.Rect.all(0),
        });

        bw.processEvents();
        bw.drawBackground();

        dvui.labelNoFmt(@src(), graphic_comp.comp.name, .{}, .{
            .id_extra = 0,
            .expand = .horizontal,
            .font = font,
            .style = style,
            .margin = dvui.Rect.all(0),
            .padding = dvui.Rect.all(1),
        });

        if (bw.hovered()) {
            switch (circuit.placement_mode) {
                .none => |*data| data.hovered_element = .{ .component = i },
                else => {},
            }
        }

        if (bw.clicked()) {
            if (select_component_id != i) {
                circuit.selection_changed = true;
            }
            circuit.selection = .{ .component = i };
        }

        bw.deinit();
    }
}

pub fn renderProperties() void {
    {
        var tl_box = dvui.box(@src(), .{ .dir = .horizontal }, tl_box_opts);
        defer tl_box.deinit();

        var tl = dvui.textLayout(@src(), .{}, tl_opts);
        defer tl.deinit();

        tl.addText("Properties", .{});
    }

    if (circuit.selection) |element| {
        switch (element) {
            .component => |comp_id| {
                var scroll = dvui.scrollArea(
                    @src(),
                    .{},
                    .{
                        .expand = .horizontal,
                    },
                );
                defer scroll.deinit();

                var selected_graphic_comp = &circuit.main_circuit.graphic_components.items[comp_id];
                var comp = &selected_graphic_comp.comp;

                dvui.label(@src(), "name", .{}, renderer.textEntryLabelOpts);

                var te = dvui.textEntry(
                    @src(),
                    .{
                        .text = .{
                            .buffer = selected_graphic_comp.name_buffer,
                        },
                    },
                    renderer.textEntryOpts,
                );

                if (dvui.firstFrame(te.data().id) or circuit.selection_changed) {
                    te.textSet(comp.name, false);
                }

                comp.name = te.getText();
                te.deinit();

                selected_graphic_comp.renderPropertyBox(circuit.selection_changed);
            },
            .wire, .ground, .label => {},
            .pin => |pin_id| {
                // TODO: there should be no scrollArea here right?
                var pin = &circuit.main_circuit.pins.items[pin_id];

                dvui.label(@src(), "name", .{}, renderer.textEntryLabelOpts);

                var te = dvui.textEntry(
                    @src(),
                    .{
                        .text = .{
                            .buffer = pin.name_buffer,
                        },
                    },
                    renderer.textEntryOpts,
                );

                if (dvui.firstFrame(te.data().id) or circuit.selection_changed) {
                    te.textSet(pin.name, false);
                }

                pin.name = te.getText();
                te.deinit();
            },
        }

        circuit.selection_changed = false;
    }
}

const AnalysisType = enum {
    dc,
    sin_ss_freq_sweep,
    transient,
};

const AnalysisMode = struct {
    var analysis_type = AnalysisType.dc;

    var transient_duration_buffer: [64]u8 = undefined;
    var transient_duration_actual: []u8 = transient_duration_buffer[0..0];
    var transient_duration: bland.Float = 0;

    var fs_start_buffer: [64]u8 = undefined;
    var fs_start_actual: []u8 = fs_start_buffer[0..0];
    var fs_start: bland.Float = 0;

    var fs_end_buffer: [64]u8 = undefined;
    var fs_end_actual: []u8 = fs_end_buffer[0..0];
    var fs_end: bland.Float = 0;

    var fs_count_buffer: [64]u8 = undefined;
    var fs_count_actual: []u8 = fs_count_buffer[0..0];
    var fs_count: bland.Float = 0;
};

pub fn renderAnalysisOptions() void {
    {
        var tl_box = dvui.box(@src(), .{ .dir = .horizontal }, tl_box_opts);
        defer tl_box.deinit();

        var tl = dvui.textLayout(@src(), .{}, tl_opts);
        defer tl.deinit();

        tl.addText("Analysis", .{});
    }

    var function_changed = false;

    {
        const scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .horizontal });
        defer scroll.deinit();

        {
            var radio_group = dvui.radioGroup(@src(), .{}, .{ .label = .{ .text = "Mode" } });
            defer radio_group.deinit();
            const entries = [_][]const u8{ "DC", "Freq. sweep", "Transient" };
            for (0..entries.len) |i| {
                const active = i == @intFromEnum(AnalysisMode.analysis_type);

                if (dvui.radio(
                    @src(),
                    active,
                    entries[i],
                    renderer.radioGroupOpts.override(.{ .id_extra = i }),
                )) {
                    AnalysisMode.analysis_type = @enumFromInt(i);
                    function_changed = true;
                }
            }
        }

        switch (AnalysisMode.analysis_type) {
            .dc => {},
            .sin_ss_freq_sweep => {
                _ = renderer.textEntrySI(
                    @src(),
                    "start frequency",
                    &AnalysisMode.fs_start_actual,
                    .frequency,
                    &AnalysisMode.fs_start,
                    function_changed,
                    .{},
                );
                _ = renderer.textEntrySI(
                    @src(),
                    "end frequency",
                    &AnalysisMode.fs_end_actual,
                    .frequency,
                    &AnalysisMode.fs_end,
                    function_changed,
                    .{},
                );
                _ = renderer.textEntrySI(
                    @src(),
                    "frequency points",
                    &AnalysisMode.fs_count_actual,
                    .dimensionless,
                    &AnalysisMode.fs_count,
                    function_changed,
                    .{},
                );
            },
            .transient => {
                _ = renderer.textEntrySI(
                    @src(),
                    "duration",
                    &AnalysisMode.transient_duration_actual,
                    .time,
                    &AnalysisMode.transient_duration,
                    function_changed,
                    .{},
                );
            },
        }
    }
}

pub fn render() void {
    const paned_opts = dvui.Options{
        .background = true,
        .min_size_content = .{ .w = 150, .h = dvui.windowRect().h },
        .border = .{ .w = 2 }, // right 2px
        .color_fill = dvui.themeGet().color(.window, .fill),
        .color_border = dvui.themeGet().color(.window, .border),
        .expand = .horizontal,
    };

    const paned_box_opts = dvui.Options{
        .background = true,
        .color_fill = dvui.themeGet().color(.window, .fill),
        .expand = .both,
    };

    // TODO: find a better way to do this
    const button_min_height = 80;
    const window_height = dvui.currentWindow().rectScale().r.h;

    {
        var vbox = dvui.box(
            @src(),
            .{ .dir = .vertical },
            .{ .expand = .horizontal },
        );
        defer vbox.deinit();

        var menu = dvui.paned(
            @src(),
            .{
                .direction = .vertical,
                .collapsed_size = 100,
            },
            paned_opts.override(.{
                .max_size_content = .height(window_height - button_min_height),
            }),
        );
        defer menu.deinit();

        if (dvui.firstFrame(menu.data().id)) {
            menu.split_ratio.* = 0.33;
        }

        if (menu.showFirst()) {
            var components_box = dvui.box(
                @src(),
                .{ .dir = .vertical },
                paned_box_opts,
            );
            renderComponentList();
            components_box.deinit();
        }

        if (menu.showSecond()) {
            var menu2 = dvui.paned(@src(), .{
                .direction = .vertical,
                .collapsed_size = 100,
            }, paned_opts);
            defer menu2.deinit();

            if (menu2.showFirst()) {
                var property_box = dvui.box(
                    @src(),
                    .{ .dir = .vertical },
                    paned_box_opts,
                );
                renderProperties();
                property_box.deinit();
            }

            if (menu2.showSecond()) {
                var analysis_box = dvui.box(
                    @src(),
                    .{ .dir = .vertical },
                    paned_box_opts,
                );
                renderAnalysisOptions();
                analysis_box.deinit();
            }
        }
    }

    {
        const vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .both,
            .background = true,
            .color_fill = dvui.themeGet().color(.window, .fill),
        });
        defer vbox.deinit();

        if (dvui.button(@src(), "analyse", .{}, .{
            .expand = .both,
            .color_border = dvui.themeGet().color(.highlight, .fill),
            .border = dvui.Rect.all(2),
            .corner_radius = dvui.Rect.all(4),
        })) {
            switch (AnalysisMode.analysis_type) {
                .dc => {
                    circuit.main_circuit.analyseDC();
                },
                .sin_ss_freq_sweep => {
                    circuit.main_circuit.analyseFrequencySweep(
                        AnalysisMode.fs_start,
                        AnalysisMode.fs_end,
                        @intFromFloat(AnalysisMode.fs_count),
                    );
                },
                .transient => {
                    circuit.main_circuit.analyseTransient(AnalysisMode.transient_duration);
                },
            }
        }
    }
}
