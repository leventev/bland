const sdl = @cImport(@cInclude("SDL2/SDL.h"));

const DEFAULT_WINDOW_WIDTH = 1024;
const DEFAULT_WINDOW_HEIGHT = 768;

const GRID_SIZE = 32;

const ScreenState = struct {
    camera_x: i32 = 0,
    camera_y: i32 = 0,
    window_x: i32 = 0,
    window_y: i32 = 0,
    width: i32 = 0,
    height: i32 = 0,
    scale: f32 = 1,

    fn cameraWidth(self: ScreenState) i32 {
        return @intFromFloat(@as(f32, @floatFromInt(DEFAULT_WINDOW_WIDTH)) * self.scale);
    }

    fn cameraHeight(self: ScreenState) i32 {
        return @intFromFloat(@as(f32, @floatFromInt(DEFAULT_WINDOW_HEIGHT)) * self.scale);
    }

    fn xscale(self: ScreenState) f32 {
        return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(DEFAULT_WINDOW_WIDTH));
    }

    fn yscale(self: ScreenState) f32 {
        return @as(f32, @floatFromInt(self.height)) / @as(f32, @floatFromInt(DEFAULT_WINDOW_HEIGHT));
    }
};

var screen_state: ScreenState = .{};
var window: *sdl.SDL_Window = undefined;
var renderer: *sdl.SDL_Renderer = undefined;

fn render() void {
    _ = sdl.SDL_SetRenderDrawColor(renderer, 45, 45, 60, 255);
    _ = sdl.SDL_RenderClear(renderer);

    const offset_x: u32 = @mod(@abs(screen_state.camera_x), GRID_SIZE);
    const offset_y: u32 = @mod(@abs(screen_state.camera_y), GRID_SIZE);

    const count_x: usize = @intCast(@divTrunc(screen_state.cameraWidth(), GRID_SIZE) + 1);
    const count_y: usize = @intCast(@divTrunc(screen_state.cameraHeight(), GRID_SIZE) + 1);

    _ = sdl.SDL_SetRenderDrawColor(renderer, 100, 100, 100, 255);

    for (0..count_x) |i| {
        for (0..count_y) |j| {
            const camera_x: i32 = @as(i32, @intCast(offset_x)) + @as(i32, @intCast(i)) * GRID_SIZE;
            const camera_y: i32 = @as(i32, @intCast(offset_y)) + @as(i32, @intCast(j)) * GRID_SIZE;
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

    _ = sdl.SDL_RenderPresent(renderer);
}

fn handle_window_event(event: *sdl.SDL_Event) void {
    switch (event.window.event) {
        sdl.SDL_WINDOWEVENT_SIZE_CHANGED => {
            screen_state.width = event.window.data1;
            screen_state.height = event.window.data2;
        },
        sdl.SDL_WINDOWEVENT_MOVED => {
            screen_state.window_x = event.window.data1;
            screen_state.window_y = event.window.data2;
        },
        else => {
            std.log.debug("unhandled window event: {}", .{event.window.type});
        },
    }
}

pub fn main() !void {
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        std.log.err("failed to initialize SDL3", .{});
        return error.FailedToInitializeSDL;
    }
    defer sdl.SDL_Quit();

    var version: sdl.SDL_version = undefined;
    sdl.SDL_GetVersion(&version);
    std.log.info("initialized SDL{}.{}.{}", .{ version.major, version.minor, version.patch });

    window = sdl.SDL_CreateWindow(
        "bland",
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        DEFAULT_WINDOW_WIDTH,
        DEFAULT_WINDOW_HEIGHT,
        sdl.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.log.err("failed to create window", .{});
        return error.FailedToCreateWindow;
    };
    defer sdl.SDL_DestroyWindow(window);

    screen_state.width = DEFAULT_WINDOW_WIDTH;
    screen_state.height = DEFAULT_WINDOW_HEIGHT;
    screen_state.camera_x = 0 - DEFAULT_WINDOW_WIDTH / 2;
    screen_state.camera_y = 0 - DEFAULT_WINDOW_HEIGHT / 2;
    std.log.info("created {}x{} pixel window", .{ screen_state.width, screen_state.height });

    renderer = sdl.SDL_CreateRenderer(window, -1, 0) orelse {
        std.log.err("failed to create renderer", .{});
        return error.FailedToCreateRenderer;
    };
    defer sdl.SDL_DestroyRenderer(renderer);

    var event: sdl.SDL_Event = undefined;
    while (sdl.SDL_WaitEvent(@ptrCast(&event)) != 0) {
        switch (event.type) {
            sdl.SDL_QUIT => {
                break;
            },
            sdl.SDL_WINDOWEVENT => {
                handle_window_event(&event);
                render();
            },
            sdl.SDL_MOUSEMOTION => {
                if (event.motion.state & sdl.SDL_BUTTON_LMASK == 0) continue;
                screen_state.camera_x -= event.motion.xrel;
                screen_state.camera_y -= event.motion.yrel;
                render();
            },
            else => {
                render();
            },
        }
    }
}

const std = @import("std");
