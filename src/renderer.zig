const std = @import("std");

const global = @import("global.zig");
const component = @import("component.zig");
const circuit = @import("circuit.zig");
const sdl = global.sdl;

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

    pub fn fromGridPosition(pos: component.GridPosition) WorldPosition {
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

fn drawRect(rect: sdl.SDL_Rect) void {
    const transformed_rect = sdl.SDL_Rect{
        .x = @intFromFloat(@as(f32, @floatFromInt(rect.x)) * screen_state.xscale()),
        .y = @intFromFloat(@as(f32, @floatFromInt(rect.y)) * screen_state.yscale()),
        .w = @intFromFloat(@as(f32, @floatFromInt(rect.w)) * screen_state.xscale()),
        .h = @intFromFloat(@as(f32, @floatFromInt(rect.h)) * screen_state.yscale()),
    };

    _ = sdl.SDL_RenderDrawRect(
        renderer,
        @ptrCast(&transformed_rect),
    );
}

fn setColor(color: u32) void {
    const r: u8 = @intCast(color >> 24);
    const g: u8 = @intCast((color >> 16) & 0xFF);
    const b: u8 = @intCast((color >> 8) & 0xFF);
    const a: u8 = @intCast(color & 0xFF);

    _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, a);
}

fn drawLine(x1: i32, y1: i32, x2: i32, y2: i32) void {
    const slope_x = x2 - x1;
    const slope_y = y2 - y1;

    const scaled_x1: i32 = @intFromFloat(@as(f32, @floatFromInt(x1)) * screen_state.xscale());
    const scaled_y1: i32 = @intFromFloat(@as(f32, @floatFromInt(y1)) * screen_state.yscale());
    const scaled_x2: i32 = scaled_x1 + @as(i32, @intFromFloat(@as(f32, @floatFromInt(slope_x)) * screen_state.xscale()));
    const scaled_y2: i32 = scaled_y1 + @as(i32, @intFromFloat(@as(f32, @floatFromInt(slope_y)) * screen_state.yscale()));

    _ = sdl.SDL_RenderDrawLine(renderer, scaled_x1, scaled_y1, scaled_x2, scaled_y2);
}

const ComponentRenderType = enum {
    normal,
    holding,
    unable_to_place,
};

fn renderColors(render_type: ComponentRenderType) struct { u32, u32 } {
    // first is the wire color, second is the component color
    switch (render_type) {
        .normal => return .{ 0x32f032ff, 0xb428e6ff },
        .holding => return .{ 0x999999ff, 0x999999ff },
        .unable_to_place => return .{ 0xbb4040ff, 0xbb4040ff },
    }
}

pub fn renderResistor(pos: component.GridPosition, rot: component.ComponentRotation, render_type: ComponentRenderType) void {
    const resistor_length = 2 * global.grid_size - 2 * global.component_wire_len;
    const resistor_width = 28;

    const world_pos = WorldPosition.fromGridPosition(pos);
    const coords = ScreenPosition.fromWorldPosition(world_pos);

    const wire_color, const resistor_color = renderColors(render_type);

    switch (rot) {
        .left, .right => {
            setColor(wire_color);
            drawLine(
                coords.x,
                coords.y - 1,
                coords.x + global.component_wire_len,
                coords.y - 1,
            );
            drawLine(
                coords.x,
                coords.y,
                coords.x + global.component_wire_len,
                coords.y,
            );

            drawLine(
                coords.x + global.component_wire_len + resistor_length,
                coords.y - 1,
                coords.x + resistor_length + 2 * global.component_wire_len,
                coords.y - 1,
            );
            drawLine(
                coords.x + global.component_wire_len + resistor_length,
                coords.y,
                coords.x + resistor_length + 2 * global.component_wire_len,
                coords.y,
            );

            const rect = sdl.SDL_Rect{
                .x = coords.x + global.component_wire_len,
                .y = coords.y - resistor_width / 2,
                .w = resistor_length,
                .h = resistor_width,
            };

            setColor(resistor_color);
            drawRect(rect);
        },
        .bottom, .top => {
            setColor(wire_color);
            drawLine(
                coords.x - 1,
                coords.y,
                coords.x - 1,
                coords.y + global.component_wire_len,
            );
            drawLine(
                coords.x,
                coords.y,
                coords.x,
                coords.y + global.component_wire_len,
            );

            drawLine(
                coords.x - 1,
                coords.y + global.component_wire_len + resistor_length,
                coords.x - 1,
                coords.y + resistor_length + 2 * global.component_wire_len,
            );
            drawLine(
                coords.x,
                coords.y + global.component_wire_len + resistor_length,
                coords.x,
                coords.y + resistor_length + 2 * global.component_wire_len,
            );

            const rect = sdl.SDL_Rect{
                .x = coords.x - resistor_width / 2,
                .y = coords.y + global.component_wire_len,
                .w = resistor_width,
                .h = resistor_length,
            };

            setColor(resistor_color);
            drawRect(rect);
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
            const screen_x: i32 = @intFromFloat(@as(f32, @floatFromInt(camera_x)) * screen_state.xscale());
            const screen_y: i32 = @intFromFloat(@as(f32, @floatFromInt(camera_y)) * screen_state.yscale());

            _ = sdl.SDL_RenderFillRect(renderer, @ptrCast(&sdl.SDL_Rect{
                .x = screen_x - 1,
                .y = screen_y - 2,
                .w = 2,
                .h = 4,
            }));
            _ = sdl.SDL_RenderFillRect(renderer, @ptrCast(&sdl.SDL_Rect{
                .x = screen_x - 2,
                .y = screen_y - 1,
                .w = 4,
                .h = 2,
            }));
        }
    }

    for (circuit.components.items) |comp| {
        comp.render();
    }

    if (circuit.held_component) |comp| {
        const grid_pos = comp.gridPositionFromMouse(circuit.held_component_rotation);
        const can_place = circuit.canPlace(grid_pos, circuit.held_component_rotation);
        const render_type = if (can_place) ComponentRenderType.holding else ComponentRenderType.unable_to_place;
        renderResistor(grid_pos, circuit.held_component_rotation, render_type);
    }

    _ = sdl.SDL_RenderPresent(renderer);
}
