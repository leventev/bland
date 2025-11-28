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
                .wire, .pin => null,
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

        var bw = dvui.ButtonWidget.init(@src(), .{}, .{
            .id_extra = i,
            .expand = .horizontal,
            .style = style,
            .margin = dvui.Rect.all(0),
            .padding = dvui.Rect.all(4),
            .corner_radius = dvui.Rect.all(0),
        });

        bw.install();
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
            .wire => {},
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

pub fn renderAnalysisOptions() void {
    {
        var tl_box = dvui.box(@src(), .{ .dir = .horizontal }, tl_box_opts);
        defer tl_box.deinit();

        var tl = dvui.textLayout(@src(), .{}, tl_opts);
        defer tl.deinit();

        tl.addText("Analysis", .{});
    }

    const AnalysisType = enum {
        dc,
        sin_ss_freq_sweep,
        transient,
    };

    const S = struct {
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

    var function_changed = false;

    const scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .horizontal });
    defer scroll.deinit();

    if (dvui.button(@src(), "analyse", .{}, .{
        .gravity_x = 0.5,
    })) {
        switch (S.analysis_type) {
            .dc => {
                circuit.main_circuit.analyseDC();
            },
            .sin_ss_freq_sweep => {
                circuit.main_circuit.analyseFrequencySweep(
                    S.fs_start,
                    S.fs_end,
                    @intFromFloat(S.fs_count),
                );
            },
            .transient => {
                circuit.main_circuit.analyseTransient(S.transient_duration);
            },
        }
    }

    {
        var radio_group = dvui.radioGroup(@src(), .{}, .{ .label = .{ .text = "Mode" } });
        defer radio_group.deinit();
        const entries = [_][]const u8{ "DC", "Freq. sweep", "Transient" };
        for (0..entries.len) |i| {
            const active = i == @intFromEnum(S.analysis_type);

            if (dvui.radio(
                @src(),
                active,
                entries[i],
                renderer.radioGroupOpts.override(.{ .id_extra = i }),
            )) {
                S.analysis_type = @enumFromInt(i);
                function_changed = true;
            }
        }
    }

    switch (S.analysis_type) {
        .dc => {},
        .sin_ss_freq_sweep => {
            _ = renderer.textEntrySI(
                @src(),
                "start frequency",
                &S.fs_start_actual,
                .frequency,
                &S.fs_start,
                function_changed,
                .{},
            );
            _ = renderer.textEntrySI(
                @src(),
                "end frequency",
                &S.fs_end_actual,
                .frequency,
                &S.fs_end,
                function_changed,
                .{},
            );
            _ = renderer.textEntrySI(
                @src(),
                "frequency points",
                &S.fs_count_actual,
                .dimensionless,
                &S.fs_count,
                function_changed,
                .{},
            );
        },
        .transient => {
            _ = renderer.textEntrySI(
                @src(),
                "duration",
                &S.transient_duration_actual,
                .time,
                &S.transient_duration,
                function_changed,
                .{},
            );
        },
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

    var menu = dvui.paned(
        @src(),
        .{
            .direction = .vertical,
            .collapsed_size = 100,
        },
        paned_opts,
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
