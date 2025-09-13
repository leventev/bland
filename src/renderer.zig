const std = @import("std");

const global = @import("global.zig");
const component = @import("component.zig");
const circuit = @import("circuit.zig");
const sidebar = @import("sidebar.zig");

const dvui = @import("dvui");
const SDLBackend = dvui.backend;
comptime {
    std.debug.assert(@hasDecl(SDLBackend, "SDLBackend"));
}
const sdl = SDLBackend.c;

const GridPosition = circuit.GridPosition;

pub var screen_state: ScreenState = .{};
pub var window: *sdl.SDL_Window = undefined;
pub var renderer: *sdl.SDL_Renderer = undefined;

const ScreenState = struct {
    camera_x: i32 = 0,
    camera_y: i32 = 0,
    window_x: i32 = 0,
    window_y: i32 = 0,
    width: i32 = 0,
    height: i32 = 0,
    scale: f32 = 1,

    fn cameraWidth(self: ScreenState) i32 {
        return @intFromFloat(@as(f32, @floatFromInt(global.default_window_width)) * self.scale);
    }

    fn cameraHeight(self: ScreenState) i32 {
        return @intFromFloat(@as(f32, @floatFromInt(global.default_window_height)) * self.scale);
    }

    fn xscale(self: ScreenState) f32 {
        return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(global.default_window_width));
    }

    fn yscale(self: ScreenState) f32 {
        return @as(f32, @floatFromInt(self.height)) / @as(f32, @floatFromInt(global.default_window_height));
    }
};

pub fn renderCenteredText(pos: dvui.Point, color: dvui.Color, text: []const u8) void {
    const f = dvui.Font{
        .id = .fromName(global.font_name),
        .size = global.font_size,
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

pub fn drawRect(rect: dvui.Rect.Physical, color: dvui.Color) void {
    dvui.Rect.stroke(rect, dvui.Rect.Physical.all(0), .{
        .color = color,
        .thickness = 1,
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

pub fn renderColors(render_type: ComponentRenderType) ComponentRenderColors {
    switch (render_type) {
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
    const wire_color = renderColors(render_type).wire_color;

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
                1,
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
                1,
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
                1,
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
                1,
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
    const wire_color = renderColors(render_type).wire_color;
    const length: f32 = @floatFromInt(wire.length * global.grid_size);

    if (render_type == .holding) {
        const rect1 = dvui.Rect.Physical{
            .x = pos.x - 3,
            .y = pos.y - 3,
            .w = 6,
            .h = 6,
        };
        drawRect(rect1, wire_color);

        const pos2 = wire.end().toCircuitPosition(circuit_rect);

        const rect2 = dvui.Rect.Physical{
            .x = pos2.x - 3,
            .y = pos2.y - 3,
            .w = 6,
            .h = 6,
        };
        drawRect(rect2, wire_color);
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
                1,
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
                1,
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
                1,
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
                1,
            );
        },
    }
}

pub fn renderCircuit() void {
    var circuit_area = dvui.box(@src(), .{
        .dir = .horizontal,
    }, .{
        .color_fill = dvui.themeGet().color(.control, .fill),
        .expand = .both,
    });
    defer circuit_area.deinit();

    const circuit_rect = circuit_area.data().rectScale().r;

    const count_x: usize = @intFromFloat(@divTrunc(circuit_rect.w, global.grid_size) + 1);
    const count_y: usize = @intFromFloat(@divTrunc(circuit_rect.h, global.grid_size) + 1);

    for (0..count_x) |i| {
        for (0..count_y) |j| {
            const x = circuit_rect.x + @as(f32, @floatFromInt(i)) * global.grid_size;
            const y = circuit_rect.y + @as(f32, @floatFromInt(j)) * global.grid_size;

            const rect1 = dvui.Rect.Physical{
                .x = x - 1,
                .y = y - 2,
                .w = 2,
                .h = 4,
            };

            const rect2 = dvui.Rect.Physical{
                .x = x - 2,
                .y = y - 1,
                .w = 4,
                .h = 2,
            };

            const col = dvui.Color{ .r = 100, .g = 100, .b = 100, .a = 255 };
            dvui.Rect.fill(rect1, dvui.Rect.Physical.all(0), .{ .color = col });
            dvui.Rect.fill(rect2, dvui.Rect.Physical.all(0), .{ .color = col });
        }
    }

    for (0.., circuit.components.items) |i, comp| {
        const render_type: ComponentRenderType = if (i == sidebar.selected_component_id)
            ComponentRenderType.selected
        else if (i == sidebar.hovered_component_id)
            ComponentRenderType.hovered
        else
            ComponentRenderType.normal;

        comp.render(circuit_rect, render_type);
    }

    for (circuit.wires.items) |wire| {
        renderWire(circuit_rect, wire, .normal);
    }

    if (circuit.placement_mode == .component) {
        const grid_pos = circuit.held_component.gridPositionFromMouse(
            circuit_rect,
            circuit.held_component_rotation,
        );
        const can_place = circuit.canPlaceComponent(
            circuit.held_component,
            grid_pos,
            circuit.held_component_rotation,
        );
        const render_type = if (can_place) ComponentRenderType.holding else ComponentRenderType.unable_to_place;
        circuit.held_component.renderHolding(
            circuit_rect,
            grid_pos,
            circuit.held_component_rotation,
            render_type,
        );
    } else if (circuit.placement_mode == .wire) {
        if (circuit.held_wire_p1) |p1| {
            const p2 = circuit.gridPositionFromMouse(circuit_rect);
            const xlen = @abs(p2.x - p1.x);
            const ylen = @abs(p2.y - p1.y);

            const wire: circuit.Wire = if (xlen >= ylen) circuit.Wire{
                .direction = .horizontal,
                .length = p2.x - p1.x,
                .pos = p1,
            } else circuit.Wire{
                .direction = .vertical,
                .length = p2.y - p1.y,
                .pos = p1,
            };

            const can_place = circuit.canPlaceWire(wire);
            const render_type = if (can_place) ComponentRenderType.holding else ComponentRenderType.unable_to_place;
            renderWire(circuit_rect, wire, render_type);
        }
    }
}

pub fn render() void {
    _ = sdl.SDL_SetRenderDrawColor(renderer, 45, 45, 60, 255);
    _ = sdl.SDL_RenderClear(renderer);

    var window_box = dvui.box(
        @src(),
        .{
            .dir = .vertical,
        },
        .{
            .expand = .both,
            .background = true,
        },
    );
    defer window_box.deinit();

    {
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

        if (dvui.menuItemLabel(@src(), "File", .{ .submenu = true }, .{})) |r| {
            var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
            defer fw.deinit();

            if (dvui.menuItemLabel(@src(), "Quit", .{}, .{ .expand = .horizontal }) != null) {
                std.process.cleanExit();
            }
        }
    }

    var paned = dvui.paned(
        @src(),
        .{
            .collapsed_size = 200,
            .direction = .horizontal,
        },
        .{
            .expand = .both,
        },
    );
    defer paned.deinit();

    if (dvui.firstFrame(paned.data().id)) {
        paned.split_ratio.* = 0.2;
    }

    if (paned.showFirst()) {
        sidebar.render();
    }

    if (paned.showSecond()) {
        renderCircuit();
    }
}
