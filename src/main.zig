const std = @import("std");

const global = @import("global.zig");
const renderer = @import("renderer.zig");
const component = @import("component.zig");
const circuit = @import("circuit.zig");

const dvui = @import("dvui");
const SDLBackend = dvui.backend;
comptime {
    std.debug.assert(@hasDecl(SDLBackend, "SDLBackend"));
}
const sdl = global.sdl;

fn handleWindowEvent(event: *sdl.SDL_Event) void {
    switch (event.type) {
        sdl.SDL_EVENT_WINDOW_RESIZED => {
            renderer.screen_state.width = event.window.data1;
            renderer.screen_state.height = event.window.data2;
        },
        sdl.SDL_EVENT_WINDOW_MOVED => {
            renderer.screen_state.window_x = event.window.data1;
            renderer.screen_state.window_y = event.window.data2;
        },
        else => {},
    }
}

fn handleKeydownEvent(allocator: std.mem.Allocator, event: *sdl.SDL_Event) void {
    if (event.key.repeat) return;

    switch (event.key.key) {
        sdl.SDLK_T => {
            circuit.held_component_rotation = switch (circuit.held_component_rotation) {
                .right => component.ComponentRotation.bottom,
                .bottom => component.ComponentRotation.left,
                .left => component.ComponentRotation.top,
                .top => component.ComponentRotation.right,
            };
        },
        sdl.SDLK_K => {
            renderer.screen_state.camera_x = 0;
            renderer.screen_state.camera_y = 0;
        },
        sdl.SDLK_ESCAPE => circuit.placement_mode = .none,
        sdl.SDLK_G => {
            circuit.placement_mode = .component;
            circuit.held_component = .ground;
        },
        sdl.SDLK_R => {
            circuit.placement_mode = .component;
            circuit.held_component = .resistor;
        },
        sdl.SDLK_V => {
            circuit.placement_mode = .component;
            circuit.held_component = .voltage_source;
        },
        sdl.SDLK_W => {
            circuit.placement_mode = .wire;
            circuit.held_wire_p1 = null;
        },
        sdl.SDLK_L => {
            dvui.toggleDebugWindow();
        },
        sdl.SDLK_A => {
            circuit.analyse(allocator);
        },
        else => {},
    }
}

fn handleMouseDownEvent(allocator: std.mem.Allocator, event: *sdl.SDL_Event) !void {
    if (event.button.button != sdl.SDL_BUTTON_LEFT) return;

    if (circuit.placement_mode == .component) {
        const grid_pos = circuit.held_component.gridPositionFromMouse(circuit.held_component_rotation);
        if (circuit.canPlaceComponent(circuit.held_component, grid_pos, circuit.held_component_rotation)) {
            var comp = component.Component{
                .pos = grid_pos,
                .inner = circuit.held_component.defaultValue(),
                .rotation = circuit.held_component_rotation,
                .name_buffer = try allocator.alloc(u8, component.max_component_name_length),
                .name = &.{},
                .terminal_node_ids = undefined,
            };
            try comp.setNewComponentName();
            try circuit.components.append(comp);
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

            if (wire.length != 0 and circuit.canPlaceWire(wire)) {
                try circuit.wires.append(wire);
                circuit.held_wire_p1 = null;
            }
        } else {
            circuit.held_wire_p1 = circuit.gridPositionFromMouse();
        }
    }
}

fn handleEvents(
    allocator: std.mem.Allocator,
    backend: *SDLBackend,
    win: *dvui.Window,
) !bool {
    var event: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&event)) {
        switch (event.type) {
            sdl.SDL_EVENT_QUIT => {
                return true;
            },
            sdl.SDL_EVENT_WINDOW_RESIZED | sdl.SDL_EVENT_WINDOW_MOVED => {
                handleWindowEvent(&event);
            },
            sdl.SDL_EVENT_KEY_DOWN => {
                handleKeydownEvent(allocator, &event);
            },
            sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                try handleMouseDownEvent(allocator, &event);
            },
            sdl.SDL_EVENT_MOUSE_MOTION => {
                if (event.motion.state & sdl.SDL_BUTTON_MMASK != 0) {
                    //renderer.screen_state.camera_x -= @intFromFloat(event.motion.xrel);
                    //renderer.screen_state.camera_y -= @intFromFloat(event.motion.yrel);
                }
            },
            else => {},
        }
        if (try backend.addEvent(win, event)) {} else {}
    }

    return false;
}

pub fn main() !void {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.log.err("failed to initialize SDL3", .{});
        return error.FailedToInitializeSDL;
    }
    defer sdl.SDL_Quit();

    const version: c_int = sdl.SDL_GetVersion();
    std.log.info("initialized SDL{}.{}.{}", .{
        sdl.SDL_VERSIONNUM_MAJOR(version),
        sdl.SDL_VERSIONNUM_MINOR(version),
        sdl.SDL_VERSIONNUM_MICRO(version),
    });

    renderer.window = sdl.SDL_CreateWindow(
        "bland",
        global.default_window_width,
        global.default_window_height,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
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

    renderer.renderer = sdl.SDL_CreateRenderer(renderer.window, null) orelse {
        std.log.err("failed to create renderer", .{});
        return error.FailedToCreateRenderer;
    };
    defer sdl.SDL_DestroyRenderer(renderer.renderer);

    const pma_blend = sdl.SDL_ComposeCustomBlendMode(
        sdl.SDL_BLENDFACTOR_ONE,
        sdl.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
        sdl.SDL_BLENDOPERATION_ADD,
        sdl.SDL_BLENDFACTOR_ONE,
        sdl.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
        sdl.SDL_BLENDOPERATION_ADD,
    );
    _ = sdl.SDL_SetRenderDrawBlendMode(renderer.renderer, pma_blend);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var backend = SDLBackend.init(renderer.window, renderer.renderer);
    defer backend.deinit();

    var win = try dvui.Window.init(@src(), allocator, backend.backend(), .{});
    defer win.deinit();

    circuit.components = std.ArrayList(component.Component).init(allocator);
    circuit.wires = std.ArrayList(circuit.Wire).init(allocator);
    defer circuit.components.deinit();
    defer circuit.wires.deinit();

    while (true) {
        try win.begin(std.time.nanoTimestamp());
        try dvui.addFont(global.font_name, global.font_data, null);

        const quit = try handleEvents(allocator, &backend, &win);
        if (quit) break;

        renderer.render();

        _ = try win.end(.{});

        try backend.textInputRect(win.textInputRequested());
        try backend.renderPresent();
    }
}
