const std = @import("std");

const global = @import("global.zig");
const component = @import("component.zig");
const circuit = @import("circuit.zig");
const renderer = @import("renderer.zig");

const dvui = @import("dvui");

pub fn renderComponentList() void {
    {
        var tl_box = dvui.box(
            @src(),
            .{
                .dir = .horizontal,
            },
            .{
                .color_fill = dvui.themeGet().color(.content, .fill),
                .expand = .horizontal,
                .background = true,
                .border = dvui.Rect{ .h = 1 },
                .color_border = dvui.themeGet().color(.content, .border),
            },
        );
        defer tl_box.deinit();

        var tl = dvui.textLayout(@src(), .{}, .{
            .color_fill = dvui.themeGet().color(.content, .fill),
            .color_text = dvui.themeGet().color(.window, .text),
            .font = dvui.themeGet().font_title,
            .gravity_x = 0.5,
        });
        defer tl.deinit();

        tl.addText("components", .{});
    }

    var scroll = dvui.scrollArea(
        @src(),
        .{},
        .{
            .expand = .horizontal,
        },
    );
    defer scroll.deinit();

    for (0.., circuit.main_circuit.graphic_components.items) |i, graphic_comp| {
        const bg = if (circuit.selected_component_id == i)
            dvui.themeGet().color(.highlight, .fill)
        else
            dvui.themeGet().color(.control, .fill);

        const font = if (circuit.selected_component_id == i)
            dvui.themeGet().font_title_2
        else
            dvui.themeGet().font_body;

        var bw = dvui.ButtonWidget.init(@src(), .{}, .{
            .id_extra = i,
            .expand = .horizontal,
            .color_fill = bg,
            .margin = dvui.Rect.all(0),
            .corner_radius = dvui.Rect.all(0),
        });

        bw.install();
        bw.processEvents();
        bw.drawBackground();

        dvui.labelNoFmt(@src(), graphic_comp.comp.name, .{}, .{
            .id_extra = 0,
            .expand = .horizontal,
            .color_text = dvui.themeGet().color(.control, .text),
            .font = font,
            .color_fill = bg,
            .margin = dvui.Rect.all(0),
            .padding = dvui.Rect.all(2),
        });

        if (bw.hovered()) {
            switch (circuit.placement_mode) {
                .none => |*data| data.hovered_component_id = i,
                else => {},
            }
        }

        if (bw.clicked()) {
            if (circuit.selected_component_id != i) {
                circuit.selected_component_changed = true;
            }
            circuit.selected_component_id = i;
        }

        bw.deinit();
    }
}

pub fn renderPropertyBox() void {
    {
        var tl_box = dvui.box(
            @src(),
            .{
                .dir = .horizontal,
            },
            .{
                .color_fill = dvui.themeGet().color(.content, .fill),
                .expand = .horizontal,
                .background = true,
                .border = dvui.Rect{ .h = 1 },
                .color_border = dvui.themeGet().color(.content, .border),
            },
        );
        defer tl_box.deinit();

        var tl = dvui.textLayout(@src(), .{}, .{
            .color_fill = dvui.themeGet().color(.content, .fill),
            .color_text = dvui.themeGet().color(.window, .text),
            .font = dvui.themeGet().font_title,
            .gravity_x = 0.5,
        });
        defer tl.deinit();

        tl.addText("properties", .{});
    }

    if (circuit.selected_component_id) |comp_id| {
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

        dvui.label(@src(), "name", .{}, .{
            .color_text = dvui.themeGet().color(.content, .text),
            .font = dvui.themeGet().font_body,
        });

        var te = dvui.textEntry(@src(), .{
            .text = .{
                .buffer = selected_graphic_comp.name_buffer,
            },
        }, .{
            .color_fill = dvui.themeGet().color(.control, .fill),
            .color_text = dvui.themeGet().color(.content, .text),
            .font = dvui.themeGet().font_body,
            .expand = .horizontal,
            .margin = dvui.Rect.all(4),
        });

        if (dvui.firstFrame(te.data().id) or circuit.selected_component_changed) {
            te.textSet(comp.name, false);
        }

        comp.name = te.getText();
        te.deinit();

        selected_graphic_comp.renderPropertyBox(circuit.selected_component_changed);
        circuit.selected_component_changed = false;
    }
}

pub fn render() void {
    var menu = dvui.paned(
        @src(),
        .{
            .direction = .vertical,
            .collapsed_size = 100,
        },
        .{
            .background = true,
            .min_size_content = .{ .w = 150, .h = dvui.windowRect().h },
            .border = .{ .w = 2 }, // right 2px
            .color_fill = dvui.themeGet().color(.window, .fill),
            .color_border = dvui.themeGet().color(.window, .border),
            .expand = .horizontal,
        },
    );
    defer menu.deinit();

    if (dvui.firstFrame(menu.data().id)) {
        menu.split_ratio.* = 0.5;
    }

    if (menu.showFirst()) {
        var components_box = dvui.box(
            @src(),
            .{ .dir = .vertical },
            .{
                .background = true,
                .color_fill = dvui.themeGet().color(.window, .fill),
                .expand = .both,
            },
        );
        renderComponentList();
        components_box.deinit();
    }

    if (menu.showSecond()) {
        var property_box = dvui.box(
            @src(),
            .{ .dir = .vertical },
            .{
                .background = true,
                .color_fill = dvui.themeGet().color(.window, .fill),
                .expand = .both,
            },
        );
        renderPropertyBox();
        property_box.deinit();
    }
}
