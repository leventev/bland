const std = @import("std");

const global = @import("global.zig");
const component = @import("component.zig");
const circuit = @import("circuit.zig");
const sidebar = @import("sidebar.zig");
const circuit_widget = @import("circuit_widget.zig");

const dvui = @import("dvui");
const GridPosition = circuit.GridPosition;

pub var dark_mode: bool = true;

pub fn renderCenteredText(pos: dvui.Point, color: dvui.Color, text: []const u8) void {
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

fn renderToolbox(allocator: std.mem.Allocator) bool {
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
            circuit.held_component_rotation = circuit.held_component_rotation.rotateClockwise();
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

        if (dvui.menuItemLabel(@src(), "Ground", .{}, .{ .expand = .horizontal }) != null) {
            circuit.placement_mode = .component;
            circuit.held_component = .ground;
            fw.close();
        }
    }

    if (dvui.menuItemLabel(@src(), "Circuit", .{ .submenu = true }, .{})) |r| {
        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        if (dvui.menuItemLabel(@src(), "Analyse", .{}, .{ .expand = .horizontal }) != null) {
            circuit.analyse(allocator);
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

pub fn render(allocator: std.mem.Allocator) !bool {
    if (!renderToolbox(allocator))
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
        try circuit_widget.renderCircuit(allocator);
    }

    if (paned.showFirst()) {
        sidebar.render();
    }

    return true;
}
