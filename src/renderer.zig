const std = @import("std");

const global = @import("global.zig");
const component = @import("component.zig");
const circuit = @import("circuit.zig");
const sdl = global.sdl;

const sdl_ttf = global.sdl_ttf;

const GridPosition = circuit.GridPosition;

const white_color = sdl.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 };

pub var screen_state: ScreenState = .{};
pub var window: *sdl.SDL_Window = undefined;
pub var renderer: *sdl.SDL_Renderer = undefined;
pub var font: *sdl_ttf.TTF_Font = undefined;

pub var hovered_component_id: ?usize = null;
pub var selected_component_id: ?usize = null;
pub var selected_component_changed: bool = false;

const dvui = @import("dvui");
const SDLBackend = dvui.backend;
comptime {
    std.debug.assert(@hasDecl(SDLBackend, "SDLBackend"));
}

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

pub const ScreenPosition = struct {
    x: i32,
    y: i32,

    pub fn fromWorldPosition(pos: WorldPosition) ScreenPosition {
        return ScreenPosition{
            .x = screen_state.camera_x + pos.x,
            .y = screen_state.camera_y + pos.y,
        };
    }
};

// TODO: WorldPosition sounds silly for a circuit simulator
// but i have no idea what to rename it to
pub const WorldPosition = struct {
    x: i32,
    y: i32,

    pub fn fromGridPosition(pos: GridPosition) WorldPosition {
        return WorldPosition{
            .x = pos.x * global.grid_size,
            .y = pos.y * global.grid_size,
        };
    }

    pub fn fromScreenPosition(pos: ScreenPosition) WorldPosition {
        return WorldPosition{
            .x = pos.x - screen_state.camera_x,
            .y = pos.y - screen_state.camera_y,
        };
    }
};

fn renderCenteredText(x: i32, y: i32, color: sdl.SDL_Color, text: []const u8) void {
    _ = color;

    const f = dvui.Font{
        .name = global.font_name,
        .size = global.font_size,
    };

    const s = dvui.Font.textSize(f, text);

    const r = dvui.Rect.Physical{
        .x = @as(f32, @floatFromInt(x)) - s.w / 2,
        .y = @as(f32, @floatFromInt(y)) - s.h / 2,
        .w = s.w,
        .h = s.h,
    };

    dvui.renderText(.{
        .color = dvui.Color.white,
        .background_color = null,
        .debug = false,
        .font = f,
        .rs = .{
            .r = r,
        },
        .text = text,
    }) catch @panic("aaa");
}

// TODO: abstract away SDL
fn drawRect(rect: sdl.SDL_Rect) void {
    const transformed_rect = sdl.SDL_FRect{
        .x = @as(f32, @floatFromInt(rect.x)) * screen_state.xscale(),
        .y = @as(f32, @floatFromInt(rect.y)) * screen_state.yscale(),
        .w = @as(f32, @floatFromInt(rect.w)) * screen_state.xscale(),
        .h = @as(f32, @floatFromInt(rect.h)) * screen_state.yscale(),
    };

    _ = sdl.SDL_RenderRect(renderer, &transformed_rect);
}

fn setColor(color: sdl.SDL_Color) void {
    _ = sdl.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);
}

fn drawLine(x1: i32, y1: i32, x2: i32, y2: i32) void {
    const slope_x = x2 - x1;
    const slope_y = y2 - y1;

    const scaled_x1: f32 = @as(f32, @floatFromInt(x1)) * screen_state.xscale();
    const scaled_y1: f32 = @as(f32, @floatFromInt(y1)) * screen_state.yscale();
    const scaled_x2: f32 = scaled_x1 + @as(f32, @floatFromInt(slope_x)) * screen_state.xscale();
    const scaled_y2: f32 = scaled_y1 + @as(f32, @floatFromInt(slope_y)) * screen_state.yscale();

    _ = sdl.SDL_RenderLine(renderer, scaled_x1, scaled_y1, scaled_x2, scaled_y2);
}

fn colorFromHex(color: u32) sdl.SDL_Color {
    return sdl.SDL_Color{
        .r = @intCast(color >> 24),
        .g = @intCast((color >> 16) & 0xFF),
        .b = @intCast((color >> 8) & 0xFF),
        .a = @intCast(color & 0xFF),
    };
}

pub const ComponentRenderType = enum {
    normal,
    holding,
    unable_to_place,
    hovered,
    selected,
};

const ComponentRenderColors = struct {
    wire_color: sdl.SDL_Color,
    component_color: sdl.SDL_Color,
};

fn renderColors(render_type: ComponentRenderType) ComponentRenderColors {
    switch (render_type) {
        .normal => return .{ .wire_color = colorFromHex(0x32f032ff), .component_color = colorFromHex(0xb428e6ff) },
        .holding => return .{ .wire_color = colorFromHex(0x999999ff), .component_color = colorFromHex(0x999999ff) },
        .unable_to_place => return .{ .wire_color = colorFromHex(0xbb4040ff), .component_color = colorFromHex(0xbb4040ff) },
        .hovered => return .{ .wire_color = colorFromHex(0x32f032ff), .component_color = colorFromHex(0x44ffffff) },
        .selected => return .{ .wire_color = colorFromHex(0x32f032ff), .component_color = colorFromHex(0xff4444ff) },
    }
}

const TerminalWire = struct {
    pos: ScreenPosition,
    pixel_length: i32,
    direction: circuit.Wire.Direction,
};

fn renderTerminalWire(wire: TerminalWire, render_type: ComponentRenderType) void {
    const pos = wire.pos;
    const wire_color = renderColors(render_type).wire_color;

    setColor(wire_color);
    switch (wire.direction) {
        .horizontal => {
            drawLine(
                pos.x,
                pos.y - 1,
                pos.x + wire.pixel_length,
                pos.y - 1,
            );

            drawLine(
                pos.x,
                pos.y,
                pos.x + wire.pixel_length,
                pos.y,
            );
        },
        .vertical => {
            drawLine(
                pos.x - 1,
                pos.y,
                pos.x - 1,
                pos.y + wire.pixel_length,
            );

            drawLine(
                pos.x,
                pos.y,
                pos.x,
                pos.y + wire.pixel_length,
            );
        },
    }
}

fn renderTerminalWires(wires: []TerminalWire, render_type: ComponentRenderType) void {
    for (wires) |wire| {
        renderTerminalWire(wire, render_type);
    }
}

pub fn renderGround(pos: GridPosition, rot: component.ComponentRotation, render_type: ComponentRenderType) void {
    const wire_pixel_len = 16;

    const world_pos = WorldPosition.fromGridPosition(pos);
    const coords = ScreenPosition.fromWorldPosition(world_pos);

    const render_colors = renderColors(render_type);

    const triangle_side = 45;
    const triangle_height = 39;

    switch (rot) {
        .right, .left => {
            const wire_off: i32 = if (rot == .right) wire_pixel_len else -wire_pixel_len;
            renderTerminalWire(TerminalWire{
                .direction = .horizontal,
                .pos = coords,
                .pixel_length = wire_off,
            }, render_type);

            const x_off: i32 = if (rot == .right) triangle_height else -triangle_height;

            setColor(render_colors.component_color);
            drawLine(
                coords.x + wire_off,
                coords.y - triangle_side / 2,
                coords.x + wire_off,
                coords.y + triangle_side / 2,
            );

            drawLine(
                coords.x + wire_off,
                coords.y - triangle_side / 2,
                coords.x + wire_off + x_off,
                coords.y,
            );

            drawLine(
                coords.x + wire_off,
                coords.y + triangle_side / 2,
                coords.x + wire_off + x_off,
                coords.y,
            );
        },
        .top, .bottom => {
            const wire_off: i32 = if (rot == .bottom) wire_pixel_len else -wire_pixel_len;
            renderTerminalWire(TerminalWire{
                .direction = .vertical,
                .pos = coords,
                .pixel_length = wire_off,
            }, render_type);

            const y_off: i32 = if (rot == .bottom) triangle_height else -triangle_height;

            setColor(render_colors.component_color);
            drawLine(
                coords.x - triangle_side / 2,
                coords.y + wire_off,
                coords.x + triangle_side / 2,
                coords.y + wire_off,
            );

            drawLine(
                coords.x - triangle_side / 2,
                coords.y + wire_off,
                coords.x,
                coords.y + wire_off + y_off,
            );

            drawLine(
                coords.x + triangle_side / 2,
                coords.y + wire_off,
                coords.x,
                coords.y + wire_off + y_off,
            );
        },
    }
}

pub fn renderVoltageSource(
    pos: GridPosition,
    rot: component.ComponentRotation,
    name: ?[]const u8,
    render_type: ComponentRenderType,
) void {
    const world_pos = WorldPosition.fromGridPosition(pos);
    const coords = ScreenPosition.fromWorldPosition(world_pos);

    const total_len = 2 * global.grid_size;
    const middle_len = 16;
    const middle_width = 4;
    const wire_len = (total_len - middle_len) / 2;

    const positive_side_len = 48;
    const negative_side_len = 32;

    const render_colors = renderColors(render_type);

    var buff: [256]u8 = undefined;
    const value = component.ComponentInnerType.voltage_source.formatValue(
        5,
        buff[0..],
    ) catch unreachable;

    switch (rot) {
        .left, .right => {
            renderTerminalWire(TerminalWire{
                .pos = coords,
                .direction = .horizontal,
                .pixel_length = wire_len,
            }, render_type);
            renderTerminalWire(TerminalWire{
                .pos = ScreenPosition{
                    .x = coords.x + global.grid_size * 2,
                    .y = coords.y,
                },
                .direction = .horizontal,
                .pixel_length = -wire_len,
            }, render_type);

            var rect1 = sdl.SDL_Rect{
                .x = coords.x + wire_len,
                .y = coords.y - positive_side_len / 2,
                .w = middle_width,
                .h = positive_side_len,
            };
            var rect2 = sdl.SDL_Rect{
                .x = coords.x + wire_len + middle_len - middle_width,
                .y = coords.y - negative_side_len / 2,
                .w = middle_width,
                .h = negative_side_len,
            };

            if (rot == .left) {
                const tmp = rect1.x;
                rect1.x = rect2.x;
                rect2.x = tmp;
            }

            setColor(render_colors.component_color);
            drawRect(rect1);
            drawRect(rect2);

            if (name) |str| {
                renderCenteredText(
                    coords.x + global.grid_size / 2,
                    coords.y - global.grid_size / 4,
                    white_color,
                    str,
                );
            }

            if (value) |str| {
                renderCenteredText(
                    coords.x + global.grid_size + global.grid_size / 2,
                    coords.y - global.grid_size / 4,
                    white_color,
                    str,
                );
            }

            const sign: i32 = if (rot == .right) -1 else 1;
            renderCenteredText(coords.x + global.grid_size + sign * 20, coords.y + global.grid_size / 4, render_colors.component_color, "+");
            renderCenteredText(coords.x + global.grid_size - sign * 20, coords.y + global.grid_size / 4, render_colors.component_color, "-");
        },
        .top, .bottom => {
            renderTerminalWire(TerminalWire{
                .pos = coords,
                .direction = .vertical,
                .pixel_length = wire_len,
            }, render_type);
            renderTerminalWire(TerminalWire{
                .pos = ScreenPosition{
                    .x = coords.x,
                    .y = coords.y + global.grid_size * 2,
                },
                .direction = .vertical,
                .pixel_length = -wire_len,
            }, render_type);

            var rect1 = sdl.SDL_Rect{
                .x = coords.x - positive_side_len / 2,
                .y = coords.y + wire_len,
                .w = positive_side_len,
                .h = middle_width,
            };
            var rect2 = sdl.SDL_Rect{
                .x = coords.x - negative_side_len / 2,
                .y = coords.y + wire_len + middle_len - middle_width,
                .w = negative_side_len,
                .h = middle_width,
            };

            if (rot == .top) {
                const tmp = rect1.y;
                rect1.y = rect2.y;
                rect2.y = tmp;
            }

            setColor(render_colors.component_color);
            drawRect(rect1);
            drawRect(rect2);
            if (name) |str| {
                renderCenteredText(
                    coords.x + global.grid_size / 2,
                    coords.y + global.grid_size - (global.font_size + 2),
                    white_color,
                    str,
                );
            }

            if (value) |str| {
                renderCenteredText(
                    coords.x + global.grid_size / 2,
                    coords.y + global.grid_size + (global.font_size + 2),
                    white_color,
                    str,
                );
            }

            const sign: i32 = if (rot == .bottom) -1 else 1;
            renderCenteredText(coords.x - global.grid_size / 4, coords.y + global.grid_size + sign * 20, render_colors.component_color, "+");
            renderCenteredText(coords.x - global.grid_size / 4, coords.y + global.grid_size - sign * 20, render_colors.component_color, "-");
        },
    }
}

pub fn renderResistor(
    pos: GridPosition,
    rot: component.ComponentRotation,
    name: ?[]const u8,
    render_type: ComponentRenderType,
) void {
    const wire_pixel_len = 25;
    const resistor_length = 2 * global.grid_size - 2 * wire_pixel_len;
    const resistor_width = 28;

    const world_pos = WorldPosition.fromGridPosition(pos);
    const coords = ScreenPosition.fromWorldPosition(world_pos);

    const resistor_color = renderColors(render_type).component_color;

    var buff: [256]u8 = undefined;
    const value = component.ComponentInnerType.resistor.formatValue(
        4,
        buff[0..],
    ) catch unreachable;

    switch (rot) {
        .left, .right => {
            renderTerminalWire(TerminalWire{
                .pos = coords,
                .direction = .horizontal,
                .pixel_length = wire_pixel_len,
            }, render_type);
            renderTerminalWire(TerminalWire{
                .pos = ScreenPosition{
                    .x = coords.x + global.grid_size * 2,
                    .y = coords.y,
                },
                .direction = .horizontal,
                .pixel_length = -wire_pixel_len,
            }, render_type);

            const rect = sdl.SDL_Rect{
                .x = coords.x + wire_pixel_len,
                .y = coords.y - resistor_width / 2,
                .w = resistor_length,
                .h = resistor_width,
            };

            setColor(resistor_color);
            drawRect(rect);
            if (name) |str| {
                renderCenteredText(
                    coords.x + global.grid_size,
                    coords.y - (resistor_width / 2 + global.font_size / 2 + 2),
                    white_color,
                    str,
                );
            }

            if (value) |str| {
                renderCenteredText(
                    coords.x + global.grid_size,
                    coords.y + resistor_width / 2 + global.font_size / 2 + 2,
                    white_color,
                    str,
                );
            }
        },
        .bottom, .top => {
            renderTerminalWire(TerminalWire{
                .pos = coords,
                .direction = .vertical,
                .pixel_length = wire_pixel_len,
            }, render_type);
            renderTerminalWire(TerminalWire{
                .pos = ScreenPosition{
                    .x = coords.x,
                    .y = coords.y + global.grid_size * 2,
                },
                .direction = .vertical,
                .pixel_length = -wire_pixel_len,
            }, render_type);

            const rect = sdl.SDL_Rect{
                .x = coords.x - resistor_width / 2,
                .y = coords.y + wire_pixel_len,
                .w = resistor_width,
                .h = resistor_length,
            };

            setColor(resistor_color);
            drawRect(rect);
            if (name) |str| {
                renderCenteredText(
                    coords.x + global.grid_size / 2,
                    coords.y + global.grid_size - (global.font_size / 2 + 8),
                    white_color,
                    str,
                );
            }

            if (value) |str| {
                renderCenteredText(
                    coords.x + global.grid_size / 2,
                    coords.y + global.grid_size + (global.font_size / 2 + 8),
                    white_color,
                    str,
                );
            }
        },
    }
}

pub fn renderWire(wire: circuit.Wire, render_type: ComponentRenderType) void {
    const wire_color = renderColors(render_type).wire_color;

    const world_pos = WorldPosition.fromGridPosition(wire.pos);
    const coords = ScreenPosition.fromWorldPosition(world_pos);

    const length: i32 = wire.length * global.grid_size;

    setColor(wire_color);

    if (render_type == .holding) {
        const rect1 = sdl.SDL_Rect{
            .x = coords.x - 3,
            .y = coords.y - 3,
            .w = 6,
            .h = 6,
        };
        drawRect(rect1);

        const world_pos2 = WorldPosition.fromGridPosition(wire.end());
        const coords2 = ScreenPosition.fromWorldPosition(world_pos2);

        const rect2 = sdl.SDL_Rect{
            .x = coords2.x - 3,
            .y = coords2.y - 3,
            .w = 6,
            .h = 6,
        };
        drawRect(rect2);
    }

    switch (wire.direction) {
        .horizontal => {
            drawLine(
                coords.x,
                coords.y - 1,
                coords.x + length,
                coords.y - 1,
            );
            drawLine(
                coords.x,
                coords.y,
                coords.x + length,
                coords.y,
            );
        },
        .vertical => {
            drawLine(
                coords.x - 1,
                coords.y,
                coords.x - 1,
                coords.y + length,
            );
            drawLine(
                coords.x,
                coords.y,
                coords.x,
                coords.y + length,
            );
        },
    }
}

pub fn renderComponentList() void {
    var tl = dvui.textLayout(@src(), .{}, .{
        .color_fill = .{ .color = global.sidebar_title_bg_color },
        .color_text = .{ .color = .white },
        .font = global.sidebar_title_font,
        .expand = .horizontal,
    });

    tl.addText("components", .{});
    tl.deinit();

    hovered_component_id = null;

    for (0.., circuit.components.items) |i, comp| {
        const bg = if (selected_component_id == i)
            global.sidebar_button_selected_color
        else
            global.sidebar_bg_color;

        const hover_bg = if (selected_component_id == i)
            global.sidebar_button_selected_color
        else
            global.sidebar_button_hover_color;

        var bw = dvui.ButtonWidget.init(@src(), .{}, .{
            .id_extra = i,
            .expand = .horizontal,
            .color_fill = .{ .color = bg },
            .color_fill_hover = .{ .color = hover_bg },
            .color_fill_press = .{ .color = hover_bg },
            .margin = dvui.Rect.all(0),
            .corner_radius = dvui.Rect.all(0),
        });

        bw.install();
        bw.processEvents();
        bw.drawBackground();

        dvui.labelNoFmt(@src(), comp.name, .{}, .{
            .id_extra = 0,
            .expand = .horizontal,
            .color_text = .{ .color = global.sidebar_text_color_normal },
            .font = global.sidebar_font,
            .color_fill = .{ .color = bg },
            .color_fill_hover = .{ .color = hover_bg },
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
        .color_fill = .{ .color = global.sidebar_title_bg_color },
        .color_text = .{ .color = .white },
        .font = global.sidebar_title_font,
        .expand = .horizontal,
    });

    tl.addText("properties", .{});
    tl.deinit();

    if (selected_component_id) |comp_id| {
        var selected_comp = &circuit.components.items[comp_id];

        dvui.label(@src(), "name", .{}, .{
            .color_text = .{ .color = global.sidebar_text_color_normal },
            .font = global.sidebar_font,
        });

        var te = dvui.textEntry(@src(), .{
            .text = .{
                .buffer = selected_comp.name_buffer,
            },
        }, .{
            .color_fill = .{ .color = global.sidebar_title_bg_color },
            .color_text = .{ .color = .white },
            .font = global.sidebar_font,
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

pub fn renderSidebar() void {
    var menu = dvui.box(
        @src(),
        .vertical,
        .{
            .background = true,
            .min_size_content = .{ .w = 150, .h = dvui.windowRect().h },
            .border = .{ .w = 2 }, // right 2px
            .color_fill = .{ .color = global.sidebar_bg_color },
            .color_border = .{ .color = global.sidebar_border_color },
        },
    );
    defer menu.deinit();

    var components_box = dvui.box(@src(), .vertical, .{
        .background = true,
        .min_size_content = .{ .w = 150, .h = 300 },
        .color_fill = .{ .color = global.sidebar_bg_color },
    });
    renderComponentList();
    components_box.deinit();

    var property_box = dvui.box(@src(), .vertical, .{
        .background = true,
        .min_size_content = .{ .w = 150, .h = 300 },
        .color_fill = .{ .color = global.sidebar_bg_color },
    });
    renderPropertyBox();
    property_box.deinit();
}

pub fn render() void {
    _ = sdl.SDL_SetRenderDrawColor(renderer, 45, 45, 60, 255);
    _ = sdl.SDL_RenderClear(renderer);

    const offset_x: u32 = @mod(@abs(screen_state.camera_x), global.grid_size);
    const offset_y: u32 = @mod(@abs(screen_state.camera_y), global.grid_size);

    const count_x: usize = @intCast(@divTrunc(screen_state.cameraWidth(), global.grid_size) + 1);
    const count_y: usize = @intCast(@divTrunc(screen_state.cameraHeight(), global.grid_size) + 1);

    _ = sdl.SDL_SetRenderDrawColor(renderer, 100, 100, 100, 255);

    for (0..count_x) |i| {
        for (0..count_y) |j| {
            const camera_x: i32 = @as(i32, @intCast(offset_x)) + @as(i32, @intCast(i)) * global.grid_size;
            const camera_y: i32 = @as(i32, @intCast(offset_y)) + @as(i32, @intCast(j)) * global.grid_size;
            const screen_x: f32 = @as(f32, @floatFromInt(camera_x)) * screen_state.xscale();
            const screen_y: f32 = @as(f32, @floatFromInt(camera_y)) * screen_state.yscale();

            const rect1 = sdl.SDL_FRect{
                .x = screen_x - 1,
                .y = screen_y - 2,
                .w = 2,
                .h = 4,
            };

            const rect2 = sdl.SDL_FRect{
                .x = screen_x - 2,
                .y = screen_y - 1,
                .w = 4,
                .h = 2,
            };

            _ = sdl.SDL_RenderFillRect(renderer, &rect1);
            _ = sdl.SDL_RenderFillRect(renderer, &rect2);
        }
    }

    for (0.., circuit.components.items) |i, comp| {
        const render_type: ComponentRenderType = if (i == selected_component_id)
            ComponentRenderType.selected
        else if (i == hovered_component_id)
            ComponentRenderType.hovered
        else
            ComponentRenderType.normal;

        comp.render(render_type);
    }

    for (circuit.wires.items) |wire| {
        renderWire(wire, .normal);
    }

    if (circuit.placement_mode == .component) {
        const grid_pos = circuit.held_component.gridPositionFromMouse(circuit.held_component_rotation);
        const can_place = circuit.canPlaceComponent(
            circuit.held_component,
            grid_pos,
            circuit.held_component_rotation,
        );
        const render_type = if (can_place) ComponentRenderType.holding else ComponentRenderType.unable_to_place;
        component.renderComponent(
            circuit.held_component,
            grid_pos,
            circuit.held_component_rotation,
            null,
            render_type,
        );
    } else if (circuit.placement_mode == .wire) {
        if (circuit.held_wire_p1) |p1| {
            const p2 = circuit.gridPositionFromMouse();
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
            renderWire(wire, render_type);
        }
    }

    renderSidebar();
}
