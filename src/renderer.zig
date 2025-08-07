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

pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    fn toSDLFRect(self: Rect) sdl.SDL_FRect {
        return sdl.SDL_FRect{
            .x = @as(f32, @floatFromInt(self.x)),
            .y = @as(f32, @floatFromInt(self.y)),
            .w = @as(f32, @floatFromInt(self.w)),
            .h = @as(f32, @floatFromInt(self.h)),
        };
    }
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub const white = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };

    pub fn fromHex(color: u32) Color {
        return Color{
            .r = @intCast(color >> 24),
            .g = @intCast((color >> 16) & 0xFF),
            .b = @intCast((color >> 8) & 0xFF),
            .a = @intCast(color & 0xFF),
        };
    }

    pub fn toSDLColor(self: Color) sdl.SDL_Color {
        return sdl.SDL_Color{
            .r = self.r,
            .g = self.g,
            .b = self.b,
            .a = self.a,
        };
    }

    pub fn toDVUIColor(self: Color) dvui.Color {
        return dvui.Color{
            .r = self.r,
            .g = self.g,
            .b = self.b,
            .a = self.a,
        };
    }
};

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

pub fn renderCenteredText(x: i32, y: i32, color: Color, text: []const u8) void {
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
        .color = color.toDVUIColor(),
        .background_color = null,
        .debug = false,
        .font = f,
        .rs = .{
            .r = r,
        },
        .text = text,
    }) catch @panic("failed to render text");
}

pub fn drawRect(rect: Rect) void {
    const sdl_rect = rect.toSDLFRect();
    _ = sdl.SDL_RenderRect(renderer, &sdl_rect);
}

pub fn fillRect(rect: Rect) void {
    const sdl_rect = rect.toSDLFRect();
    _ = sdl.SDL_RenderFillRect(renderer, &sdl_rect);
}

pub fn setColor(color: Color) void {
    const sdl_color = color.toSDLColor();
    _ = sdl.SDL_SetRenderDrawColor(renderer, sdl_color.r, sdl_color.g, sdl_color.b, sdl_color.a);
}

pub fn drawLine(x1: i32, y1: i32, x2: i32, y2: i32) void {
    const slope_x = x2 - x1;
    const slope_y = y2 - y1;

    const scaled_x1: f32 = @as(f32, @floatFromInt(x1)) * screen_state.xscale();
    const scaled_y1: f32 = @as(f32, @floatFromInt(y1)) * screen_state.yscale();
    const scaled_x2: f32 = scaled_x1 + @as(f32, @floatFromInt(slope_x)) * screen_state.xscale();
    const scaled_y2: f32 = scaled_y1 + @as(f32, @floatFromInt(slope_y)) * screen_state.yscale();

    _ = sdl.SDL_RenderLine(renderer, scaled_x1, scaled_y1, scaled_x2, scaled_y2);
}

pub const ComponentRenderType = enum {
    normal,
    holding,
    unable_to_place,
    hovered,
    selected,
};

const ComponentRenderColors = struct {
    wire_color: Color,
    component_color: Color,
};

pub fn renderColors(render_type: ComponentRenderType) ComponentRenderColors {
    switch (render_type) {
        .normal => return .{ .wire_color = Color.fromHex(0x32f032ff), .component_color = Color.fromHex(0xb428e6ff) },
        .holding => return .{ .wire_color = Color.fromHex(0x999999ff), .component_color = Color.fromHex(0x999999ff) },
        .unable_to_place => return .{ .wire_color = Color.fromHex(0xbb4040ff), .component_color = Color.fromHex(0xbb4040ff) },
        .hovered => return .{ .wire_color = Color.fromHex(0x32f032ff), .component_color = Color.fromHex(0x44ffffff) },
        .selected => return .{ .wire_color = Color.fromHex(0x32f032ff), .component_color = Color.fromHex(0xff4444ff) },
    }
}

pub const TerminalWire = struct {
    pos: ScreenPosition,
    pixel_length: i32,
    direction: circuit.Wire.Direction,
};

pub fn renderTerminalWire(wire: TerminalWire, render_type: ComponentRenderType) void {
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

pub fn renderWire(wire: circuit.Wire, render_type: ComponentRenderType) void {
    const wire_color = renderColors(render_type).wire_color;

    const world_pos = WorldPosition.fromGridPosition(wire.pos);
    const coords = ScreenPosition.fromWorldPosition(world_pos);

    const length: i32 = wire.length * global.grid_size;

    setColor(wire_color);

    if (render_type == .holding) {
        const rect1 = Rect{
            .x = coords.x - 3,
            .y = coords.y - 3,
            .w = 6,
            .h = 6,
        };
        drawRect(rect1);

        const world_pos2 = WorldPosition.fromGridPosition(wire.end());
        const coords2 = ScreenPosition.fromWorldPosition(world_pos2);

        const rect2 = Rect{
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
        const render_type: ComponentRenderType = if (i == sidebar.selected_component_id)
            ComponentRenderType.selected
        else if (i == sidebar.hovered_component_id)
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
        circuit.held_component.renderHolding(
            grid_pos,
            circuit.held_component_rotation,
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

    sidebar.render();
}
