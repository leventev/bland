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
const sdl = SDLBackend.c;

fn handleKeydownEvent(allocator: std.mem.Allocator, event: *sdl.SDL_Event) void {
    _ = allocator;
    _ = event;
    //if (event.key.repeat) return;
    //
    //switch (event.key.key) {
    //    sdl.SDLK_T => {
    //        circuit.held_component_rotation = switch (circuit.held_component_rotation) {
    //            .right => component.Component.Rotation.bottom,
    //            .bottom => component.Component.Rotation.left,
    //            .left => component.Component.Rotation.top,
    //            .top => component.Component.Rotation.right,
    //        };
    //    },
    //    sdl.SDLK_K => {
    //        renderer.screen_state.camera_x = 0;
    //        renderer.screen_state.camera_y = 0;
    //    },
    //    sdl.SDLK_ESCAPE => circuit.placement_mode = .none,
    //    sdl.SDLK_G => {
    //        circuit.placement_mode = .component;
    //        circuit.held_component = .ground;
    //    },
    //    sdl.SDLK_R => {
    //        circuit.placement_mode = .component;
    //        circuit.held_component = .resistor;
    //    },
    //    sdl.SDLK_V => {
    //        circuit.placement_mode = .component;
    //        circuit.held_component = .voltage_source;
    //    },
    //    sdl.SDLK_W => {
    //        circuit.placement_mode = .wire;
    //        circuit.held_wire_p1 = null;
    //    },
    //    sdl.SDLK_L => {
    //        dvui.toggleDebugWindow();
    //    },
    //    sdl.SDLK_A => {
    //        circuit.analyse(allocator);
    //    },
    //    else => {},
    //}
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
            sdl.SDL_EVENT_KEY_DOWN => {
                handleKeydownEvent(allocator, &event);
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

    circuit.components = std.array_list.Managed(component.Component).init(allocator);
    circuit.wires = std.array_list.Managed(circuit.Wire).init(allocator);
    defer circuit.components.deinit();
    defer circuit.wires.deinit();

    var running = true;
    while (running) {
        try win.begin(std.time.nanoTimestamp());
        try dvui.addFont(global.font_name, global.font_data, null);

        const quit = try handleEvents(allocator, &backend, &win);
        if (quit) break;

        running = renderer.render(allocator) catch @panic("err");

        _ = try win.end(.{});

        try backend.textInputRect(win.textInputRequested());
        try backend.renderPresent();
    }
}
