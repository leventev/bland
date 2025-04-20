const std = @import("std");

const global = @import("global.zig");
const renderer = @import("renderer.zig");
const component = @import("component.zig");
const circuit = @import("circuit.zig");
const sdl = global.sdl;

fn handleWindowEvent(event: *sdl.SDL_Event) void {
    switch (event.window.event) {
        sdl.SDL_WINDOWEVENT_SIZE_CHANGED => {
            renderer.screen_state.width = event.window.data1;
            renderer.screen_state.height = event.window.data2;
        },
        sdl.SDL_WINDOWEVENT_MOVED => {
            renderer.screen_state.window_x = event.window.data1;
            renderer.screen_state.window_y = event.window.data2;
        },
        else => {
            std.log.debug("unhandled window event: {}", .{event.window.type});
        },
    }
}

fn handleKeydownEvent(event: *sdl.SDL_Event) void {
    if (event.key.repeat != 0) return;

    switch (event.key.keysym.sym) {
        sdl.SDLK_t => {
            circuit.held_component_rotation = switch (circuit.held_component_rotation) {
                .right => component.ComponentRotation.bottom,
                .bottom => component.ComponentRotation.left,
                .left => component.ComponentRotation.top,
                .top => component.ComponentRotation.right,
            };
        },
        sdl.SDLK_k => {
            renderer.screen_state.camera_x = 0;
            renderer.screen_state.camera_y = 0;
        },
        sdl.SDLK_ESCAPE => circuit.placement_mode = .none,
        sdl.SDLK_r => circuit.placement_mode = .component,
        sdl.SDLK_w => {
            circuit.placement_mode = .wire;
            circuit.held_wire_p1 = null;
        },
        else => {},
    }
}

fn handleMouseDownEvent(event: *sdl.SDL_Event) !void {
    if (event.button.button != sdl.SDL_BUTTON_LEFT) return;

    if (circuit.placement_mode == .component) {
        const grid_pos = circuit.held_component.gridPositionFromMouse(circuit.held_component_rotation);
        if (circuit.canPlace(grid_pos, circuit.held_component_rotation)) {
            try circuit.components.append(component.Component{
                .pos = grid_pos,
                .inner = .{ .resistor = 0 },
                .rotation = circuit.held_component_rotation,
            });
        }
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

            if (wire.length != 0) {
                try circuit.wires.append(wire);
                circuit.held_wire_p1 = null;
            }
        } else {
            circuit.held_wire_p1 = circuit.gridPositionFromMouse();
        }
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

    renderer.window = sdl.SDL_CreateWindow(
        "bland",
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        global.default_window_width,
        global.default_window_height,
        sdl.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.log.err("failed to create window", .{});
        return error.FailedToCreateWindow;
    };
    defer sdl.SDL_DestroyWindow(renderer.window);

    renderer.screen_state.width = global.default_window_width;
    renderer.screen_state.height = global.default_window_height;
    renderer.screen_state.camera_x = 0;
    renderer.screen_state.camera_y = 0;
    std.log.info("created {}x{} pixel window", .{ renderer.screen_state.width, renderer.screen_state.height });

    renderer.renderer = sdl.SDL_CreateRenderer(renderer.window, -1, 0) orelse {
        std.log.err("failed to create renderer", .{});
        return error.FailedToCreateRenderer;
    };
    defer sdl.SDL_DestroyRenderer(renderer.renderer);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    circuit.components = std.ArrayList(component.Component).init(allocator);
    circuit.wires = std.ArrayList(circuit.Wire).init(allocator);
    defer circuit.components.deinit();
    defer circuit.wires.deinit();

    var event: sdl.SDL_Event = undefined;
    while (sdl.SDL_WaitEvent(@ptrCast(&event)) != 0) {
        switch (event.type) {
            sdl.SDL_QUIT => {
                break;
            },
            sdl.SDL_WINDOWEVENT => {
                handleWindowEvent(&event);
            },
            sdl.SDL_KEYDOWN => {
                handleKeydownEvent(&event);
            },
            sdl.SDL_MOUSEBUTTONDOWN => {
                try handleMouseDownEvent(&event);
            },
            sdl.SDL_MOUSEMOTION => {
                if (event.motion.state & sdl.SDL_BUTTON_MMASK != 0) {
                    renderer.screen_state.camera_x -= event.motion.xrel;
                    renderer.screen_state.camera_y -= event.motion.yrel;
                }
            },
            else => {},
        }
        renderer.render();
    }
}
