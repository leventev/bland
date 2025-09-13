const std = @import("std");

const global = @import("global.zig");
const component = @import("component.zig");
const circuit = @import("circuit.zig");
const renderer = @import("renderer.zig");

const dvui = @import("dvui");
const SDLBackend = dvui.backend;
comptime {
    std.debug.assert(@hasDecl(SDLBackend, "SDLBackend"));
}

pub const title_font = dvui.Font{
    .id = dvui.Font.FontId.fromName(global.font_name),
    .size = 22,
};

pub const normal_font = dvui.Font{
    .id = dvui.Font.FontId.fromName(global.font_name),
    .size = 19,
};

pub const bg_color = dvui.Color{
    .r = 40,
    .g = 40,
    .b = 55,
    .a = 255,
};

pub const button_hover_color = dvui.Color{
    .r = 60,
    .g = 60,
    .b = 80,
    .a = 255,
};

pub const button_selected_color = dvui.Color{
    .r = 50,
    .g = 50,
    .b = 65,
    .a = 255,
};

pub const title_bg_color = dvui.Color{
    .r = 35,
    .g = 35,
    .b = 48,
    .a = 255,
};

pub const border_color = dvui.Color{
    .r = 30,
    .g = 30,
    .b = 43,
    .a = 255,
};

pub const text_color_normal = dvui.Color{
    .r = 220,
    .g = 220,
    .b = 220,
    .a = 255,
};

pub var hovered_component_id: ?usize = null;
pub var selected_component_id: ?usize = null;
pub var selected_component_changed: bool = false;

pub fn renderComponentList() void {
    var tl = dvui.textLayout(@src(), .{}, .{
        .color_fill = title_bg_color,
        .color_text = .white,
        .font = title_font,
        .expand = .horizontal,
    });

    tl.addText("components", .{});
    tl.deinit();

    hovered_component_id = null;

    for (0.., circuit.components.items) |i, comp| {
        const bg = if (selected_component_id == i)
            button_selected_color
        else
            bg_color;

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

        dvui.labelNoFmt(@src(), comp.name, .{}, .{
            .id_extra = 0,
            .expand = .horizontal,
            .color_text = text_color_normal,
            .font = normal_font,
            .color_fill = bg,
            .margin = dvui.Rect.all(0),
        });

        if (bw.hovered()) {
            hovered_component_id = i;
        }

        if (bw.clicked()) {
            if (selected_component_id != i) {
                selected_component_changed = true;
            }
            selected_component_id = i;
        }

        bw.deinit();
    }
}

pub fn renderPropertyBox() void {
    var tl = dvui.textLayout(@src(), .{}, .{
        .color_fill = title_bg_color,
        .color_text = .white,
        .font = title_font,
        .expand = .horizontal,
    });

    tl.addText("properties", .{});
    tl.deinit();

    if (selected_component_id) |comp_id| {
        var selected_comp = &circuit.components.items[comp_id];

        dvui.label(@src(), "name", .{}, .{
            .color_text = text_color_normal,
            .font = normal_font,
        });

        var te = dvui.textEntry(@src(), .{
            .text = .{
                .buffer = selected_comp.name_buffer,
            },
        }, .{
            .color_fill = title_bg_color,
            .color_text = .white,
            .font = normal_font,
            .max_size_content = .width(100),
        });

        if (dvui.firstFrame(te.data().id) or selected_component_changed) {
            selected_component_changed = false;
            te.textSet(selected_comp.name, false);
        }

        selected_comp.name = te.getText();

        te.deinit();
    }
}

pub fn render() void {
    var menu = dvui.box(
        @src(),
        .{
            .dir = .vertical,
        },
        .{
            .background = true,
            .min_size_content = .{ .w = 150, .h = dvui.windowRect().h },
            .border = .{ .w = 2 }, // right 2px
            .color_fill = bg_color,
            .color_border = border_color,
            .expand = .horizontal,
        },
    );
    defer menu.deinit();

    var components_box = dvui.box(
        @src(),
        .{ .dir = .vertical },
        .{
            .background = true,
            .min_size_content = .{ .w = 150, .h = 300 },
            .color_fill = bg_color,
            .expand = .horizontal,
        },
    );
    renderComponentList();
    components_box.deinit();

    var property_box = dvui.box(
        @src(),
        .{ .dir = .vertical },
        .{
            .background = true,
            .min_size_content = .{ .w = 150, .h = 300 },
            .color_fill = bg_color,
            .expand = .horizontal,
        },
    );
    renderPropertyBox();
    property_box.deinit();
}
