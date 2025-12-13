const std = @import("std");
const dvui = @import("dvui");
const bland = @import("bland");

const renderer = @import("renderer.zig");
const circuit = @import("circuit.zig");
const component = @import("component.zig");
const global = @import("global.zig");
const VectorRenderer = @import("VectorRenderer.zig");

const ElementRenderType = renderer.ElementRenderType;

var mouse_pos: dvui.Point.Physical = undefined;

var camera_x: f32 = 0;
var camera_y: f32 = 0;
pub var zoom_scale: f32 = 1;

const max_zoom = 3.0;
const min_zoom = 0.75;

pub fn initKeybinds(allocator: std.mem.Allocator) !void {
    const win = dvui.currentWindow();
    try win.keybinds.putNoClobber(allocator, "normal_mode", .{ .key = .escape, .control = false, .shift = false });
    try win.keybinds.putNoClobber(allocator, "register_placement_mode", .{ .key = .r, .control = false, .shift = false });
    try win.keybinds.putNoClobber(allocator, "voltage_source_placement_mode", .{ .key = .v, .control = false, .shift = false });
    try win.keybinds.putNoClobber(allocator, "current_source_placement_mode", .{ .key = .i, .control = false, .shift = false });
    try win.keybinds.putNoClobber(allocator, "ground_placement_mode", .{ .key = .g, .control = false, .shift = false });
    try win.keybinds.putNoClobber(allocator, "capacitor_placement_mode", .{ .key = .c, .control = false, .shift = false });
    try win.keybinds.putNoClobber(allocator, "inductor_placement_mode", .{ .key = .l, .control = false, .shift = false });
    try win.keybinds.putNoClobber(allocator, "diode_placement_mode", .{ .key = .d, .control = false, .shift = false });
    try win.keybinds.putNoClobber(allocator, "wire_placement_mode", .{ .key = .w, .control = false, .shift = false });
    try win.keybinds.putNoClobber(allocator, "rotate", .{ .key = .r, .control = true, .shift = false });
    try win.keybinds.putNoClobber(allocator, "open_debug_window", .{ .key = .o, .control = false, .shift = false });
    try win.keybinds.putNoClobber(allocator, "pin_placement_mode", .{ .key = .p, .control = false, .shift = false });
    try win.keybinds.putNoClobber(allocator, "delete", .{ .key = .delete, .control = false, .shift = false });
}

fn checkForKeybinds(ev: dvui.Event.Key) !void {
    if (ev.matchBind("normal_mode") and ev.action == .down) {
        circuit.placement_mode = .{ .none = .{ .hovered_element = null } };
    }

    if (ev.matchBind("register_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .{ .new_component = .{ .device_type = .resistor } };
    }

    if (ev.matchBind("voltage_source_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .{ .new_component = .{ .device_type = .voltage_source } };
    }

    if (ev.matchBind("current_source_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .{ .new_component = .{ .device_type = .current_source } };
    }

    if (ev.matchBind("ground_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .{ .new_ground = {} };
    }

    if (ev.matchBind("capacitor_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .{ .new_component = .{ .device_type = .capacitor } };
    }

    if (ev.matchBind("inductor_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .{ .new_component = .{ .device_type = .inductor } };
    }

    if (ev.matchBind("diode_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .{ .new_component = .{ .device_type = .diode } };
    }

    if (ev.matchBind("wire_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .{ .new_wire = .{ .held_wire_p1 = null } };
    }

    if (ev.matchBind("rotate") and ev.action == .down) {
        circuit.placement_rotation = circuit.placement_rotation.rotateClockwise();
    }

    if (ev.matchBind("open_debug_window") and ev.action == .down) {
        dvui.toggleDebugWindow();
    }

    if (ev.matchBind("pin_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .new_pin;
    }

    if (ev.matchBind("delete") and ev.action == .down) {
        circuit.delete();
    }
}

fn findHoveredElement(viewport: dvui.Rect.Physical, m_pos: dvui.Point.Physical) void {
    switch (circuit.placement_mode) {
        .none => |*data| {
            const mouse_grid_pos = screenToWorld(viewport, m_pos, zoom_scale);
            // priority: pin > comp > ground > wire
            for (circuit.main_circuit.pins.items, 0..) |pin, pin_id| {
                const hovered = pin.hovered(mouse_grid_pos, zoom_scale);

                if (hovered) {
                    data.hovered_element = .{ .pin = pin_id };
                    return;
                }
            }

            for (circuit.main_circuit.graphic_components.items, 0..) |graphic_comp, comp_id| {
                const hovered: bool = graphic_comp.hovered(mouse_grid_pos, zoom_scale);
                if (hovered) {
                    data.hovered_element = .{ .component = comp_id };
                    return;
                }
            }

            for (circuit.main_circuit.grounds.items, 0..) |ground, ground_id| {
                const hovered = ground.hovered(
                    mouse_grid_pos,
                    zoom_scale,
                );

                if (hovered) {
                    data.hovered_element = .{ .ground = ground_id };
                    return;
                }
            }

            for (circuit.main_circuit.wires.items, 0..) |wire, wire_id| {
                const hovered = wire.hovered(mouse_grid_pos, zoom_scale);

                if (hovered) {
                    data.hovered_element = .{ .wire = wire_id };
                    return;
                }
            }

            data.hovered_element = null;
        },
        else => {},
    }
}
fn handleMouseEvent(gpa: std.mem.Allocator, viewport: dvui.Rect.Physical, ev: dvui.Event.Mouse) !void {
    findHoveredElement(viewport, ev.p);
    switch (ev.action) {
        .motion => {
            if (circuit.mb1_click_pos) |_| {
                switch (circuit.placement_mode) {
                    .none => |data| {
                        if (data.hovered_element) |element| {
                            switch (element) {
                                .component => |comp_id| {
                                    circuit.placement_mode = .{
                                        .dragging_component = .{
                                            .comp_id = comp_id,
                                        },
                                    };

                                    const comp = circuit.main_circuit.graphic_components.items[comp_id];
                                    circuit.placement_rotation = comp.rotation;
                                },
                                .ground => |ground_id| {
                                    circuit.placement_mode = .{
                                        .dragging_ground = .{
                                            .ground_id = ground_id,
                                        },
                                    };
                                    const gnd = circuit.main_circuit.grounds.items[ground_id];
                                    circuit.placement_rotation = gnd.rotation;
                                },
                                .wire => |wire_id| {
                                    const mouse_grid_pos = screenToWorld(viewport, ev.p, zoom_scale);
                                    const wire = circuit.main_circuit.wires.items[wire_id];
                                    const offset: f32 = switch (wire.direction) {
                                        .vertical => mouse_grid_pos.y - @as(f32, @floatFromInt(wire.pos.y)),
                                        .horizontal => mouse_grid_pos.x - @as(f32, @floatFromInt(wire.pos.x)),
                                    };
                                    circuit.placement_mode = .{
                                        .dragging_wire = .{
                                            .wire_id = wire_id,
                                            .offset = offset,
                                        },
                                    };
                                },
                                .pin => |pin_id| {
                                    circuit.placement_mode = .{
                                        .dragging_pin = .{
                                            .pin_id = pin_id,
                                        },
                                    };

                                    const pin = circuit.main_circuit.pins.items[pin_id];
                                    circuit.placement_rotation = pin.rotation;
                                },
                            }
                        } else {
                            camera_x -= ev.action.motion.x;
                            camera_y -= ev.action.motion.y;
                        }
                    },
                    else => {},
                }
            }
        },
        .release => {
            if (ev.button == .left) {
                circuit.mb1_click_pos = null;
                switch (circuit.placement_mode) {
                    .dragging_component => |data| {
                        var comp = &circuit.main_circuit.graphic_components.items[data.comp_id];
                        const device_type = @as(bland.Component.DeviceType, comp.comp.device);

                        const grid_pos = component.gridPositionFromScreenPos(
                            device_type,
                            viewport,
                            ev.p,
                            circuit.placement_rotation,
                        );

                        if (circuit.main_circuit.canPlaceComponent(
                            device_type,
                            grid_pos,
                            circuit.placement_rotation,
                            data.comp_id,
                        )) {
                            comp.pos = grid_pos;
                            comp.rotation = circuit.placement_rotation;
                        }

                        circuit.placement_mode = .{
                            .none = .{
                                .hovered_element = null,
                            },
                        };
                    },
                    .dragging_wire => |data| {
                        var wire = &circuit.main_circuit.wires.items[data.wire_id];

                        const m_grid_pos = screenToWorld(viewport, mouse_pos, zoom_scale);
                        const adjusted_pos: circuit.GridSubposition = switch (wire.direction) {
                            .vertical => .{
                                .x = m_grid_pos.x,
                                .y = m_grid_pos.y - data.offset,
                            },
                            .horizontal => .{
                                .x = m_grid_pos.x - data.offset,
                                .y = m_grid_pos.y,
                            },
                        };

                        const grid_pos: circuit.GridPosition = .{
                            .x = @intFromFloat(@round(adjusted_pos.x)),
                            .y = @intFromFloat(@round(adjusted_pos.y)),
                        };

                        if (circuit.main_circuit.canPlaceWire(
                            .{
                                .direction = wire.direction,
                                .length = wire.length,
                                .pos = grid_pos,
                            },
                            data.wire_id,
                        )) {
                            wire.pos = grid_pos;
                        }

                        circuit.placement_mode = .{
                            .none = .{
                                .hovered_element = null,
                            },
                        };
                    },
                    .dragging_pin => |data| {
                        var pin = &circuit.main_circuit.pins.items[data.pin_id];

                        const grid_pos = nearestGridPosition(
                            viewport,
                            ev.p,
                        );

                        if (circuit.main_circuit.canPlacePin(
                            grid_pos,
                            circuit.placement_rotation,
                            data.pin_id,
                        )) {
                            pin.pos = grid_pos;
                            pin.rotation = circuit.placement_rotation;
                        }

                        circuit.placement_mode = .{
                            .none = .{
                                .hovered_element = null,
                            },
                        };
                    },
                    .dragging_ground => |data| {
                        var ground = &circuit.main_circuit.grounds.items[data.ground_id];

                        const grid_pos = nearestGridPosition(viewport, ev.p);

                        if (circuit.main_circuit.canPlaceGround(
                            grid_pos,
                            circuit.placement_rotation,
                            data.ground_id,
                        )) {
                            ground.pos = grid_pos;
                            ground.rotation = circuit.placement_rotation;
                        }

                        circuit.placement_mode = .{
                            .none = .{
                                .hovered_element = null,
                            },
                        };
                    },
                    else => {},
                }
            }
        },
        .press => {
            if (ev.button == .left)
                circuit.mb1_click_pos = ev.p;
            switch (circuit.placement_mode) {
                .none => |data| {
                    if (data.hovered_element) |element| {
                        switch (element) {
                            .component => |comp_id| {
                                circuit.selection_changed = true;
                                circuit.selection = .{ .component = comp_id };
                            },
                            .wire => |wire_id| {
                                circuit.selection_changed = true;
                                circuit.selection = .{ .wire = wire_id };
                            },
                            .pin => |pin_id| {
                                circuit.selection_changed = true;
                                circuit.selection = .{ .pin = pin_id };
                            },
                            .ground => |ground_id| {
                                circuit.selection_changed = true;
                                circuit.selection = .{ .ground = ground_id };
                            },
                        }
                    }
                },
                .dragging_component => |data| {
                    _ = data;
                    std.log.warn("unimplemented", .{});
                },
                .dragging_ground => {},
                .dragging_wire => {},
                .dragging_pin => {},
                .new_ground => {
                    const grid_pos = nearestGridPosition(viewport, mouse_pos);

                    if (circuit.main_circuit.canPlaceGround(grid_pos, circuit.placement_rotation, null)) {
                        try circuit.main_circuit.grounds.append(
                            circuit.main_circuit.allocator,
                            circuit.Ground{
                                .pos = grid_pos,
                                .rotation = circuit.placement_rotation,
                            },
                        );
                    }
                },
                .new_component => |data| {
                    const grid_pos = component.gridPositionFromScreenPos(
                        data.device_type,
                        viewport,
                        mouse_pos,
                        circuit.placement_rotation,
                    );

                    if (circuit.main_circuit.canPlaceComponent(
                        data.device_type,
                        grid_pos,
                        circuit.placement_rotation,
                        null,
                    )) {
                        const graphic_comp = try component.GraphicComponent.init(
                            gpa,
                            grid_pos,
                            circuit.placement_rotation,
                            data.device_type,
                        );
                        try circuit.main_circuit.graphic_components.append(
                            circuit.main_circuit.allocator,
                            graphic_comp,
                        );
                    }
                },
                .new_wire => |*data| {
                    if (data.held_wire_p1) |p1| {
                        const p2 = nearestGridPosition(viewport, mouse_pos);
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

                        if (wire.length != 0 and circuit.main_circuit.canPlaceWire(wire, null)) {
                            try circuit.main_circuit.wires.append(
                                circuit.main_circuit.allocator,
                                wire,
                            );
                            data.held_wire_p1 = null;
                        }
                    } else {
                        data.held_wire_p1 = nearestGridPosition(viewport, mouse_pos);
                    }
                },
                .new_pin => {
                    const grid_pos = nearestGridPosition(viewport, mouse_pos);

                    if (circuit.main_circuit.canPlacePin(grid_pos, circuit.placement_rotation, null)) {
                        const pin = try circuit.GraphicCircuit.Pin.init(
                            gpa,
                            grid_pos,
                            circuit.placement_rotation,
                        );
                        try circuit.main_circuit.pins.append(gpa, pin);
                    }
                },
            }
        },
        .wheel_y => |scroll_y| {
            const factor = std.math.exp(scroll_y * 0.01);
            const new_zoom = std.math.clamp(zoom_scale * factor, min_zoom, max_zoom);
            adjustCameraForZoom(viewport, ev.p, zoom_scale, new_zoom);
            zoom_scale = new_zoom;
        },
        else => {},
    }
}

fn handleCircuitAreaEvents(allocator: std.mem.Allocator, circuit_area: *dvui.BoxWidget) !void {
    for (dvui.events()) |*ev| {
        switch (ev.evt) {
            .mouse => |mouse_ev| {
                if (!circuit_area.matchEvent(ev)) continue;
                mouse_pos = mouse_ev.p;
                const circuit_rect = circuit_area.data().rectScale().r;
                try handleMouseEvent(allocator, circuit_rect, mouse_ev);
            },
            .key => |key_ev| {
                if (ev.target_widgetId != null) continue;
                try checkForKeybinds(key_ev);
            },
            .text => {},
            else => {},
        }
    }
}

fn renderHoldingComponent(
    device_type: bland.Component.DeviceType,
    vector_renderer: *const VectorRenderer,
    exclude_comp_id: ?usize,
) !void {
    std.debug.assert(vector_renderer.output == .screen);
    const screen = vector_renderer.output.screen;

    const grid_pos = component.gridPositionFromScreenPos(
        device_type,
        screen.viewport,
        mouse_pos,
        circuit.placement_rotation,
    );

    const can_place = circuit.main_circuit.canPlaceComponent(
        device_type,
        grid_pos,
        circuit.placement_rotation,
        exclude_comp_id,
    );
    const render_type = if (can_place)
        ElementRenderType.holding
    else
        ElementRenderType.unable_to_place;

    try component.renderComponent(
        device_type,
        vector_renderer,
        grid_pos,
        circuit.placement_rotation,
        render_type,
        &circuit.main_circuit.junctions,
    );
}

fn renderHoldingWire(
    vector_renderer: *const VectorRenderer,
    held_wire_p1: ?circuit.GridPosition,
) !void {
    std.debug.assert(vector_renderer.output == .screen);
    const screen = vector_renderer.output.screen;

    const p1 = held_wire_p1 orelse return;
    const p2 = nearestGridPosition(screen.viewport, mouse_pos);
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

    if (wire.length == 0) return;

    const can_place = circuit.main_circuit.canPlaceWire(wire, null);
    const render_type = if (can_place)
        ElementRenderType.holding
    else
        ElementRenderType.unable_to_place;

    try renderer.renderWire(vector_renderer, wire, render_type, &circuit.main_circuit.junctions);
}

fn renderHoldingGround(vector_renderer: *const VectorRenderer, exclude_ground_id: ?usize) !void {
    std.debug.assert(vector_renderer.output == .screen);
    const screen = vector_renderer.output.screen;

    const grid_pos = nearestGridPosition(
        screen.viewport,
        mouse_pos,
    );

    const can_place = circuit.main_circuit.canPlaceGround(
        grid_pos,
        circuit.placement_rotation,
        exclude_ground_id,
    );
    const render_type = if (can_place)
        ElementRenderType.holding
    else
        ElementRenderType.unable_to_place;

    try renderer.renderGround(
        vector_renderer,
        grid_pos,
        circuit.placement_rotation,
        render_type,
        &circuit.main_circuit.junctions,
    );
}

fn renderHoldingPin(vector_renderer: *const VectorRenderer) !void {
    std.debug.assert(vector_renderer.output == .screen);
    const screen = vector_renderer.output.screen;

    const grid_pos = nearestGridPosition(
        screen.viewport,
        mouse_pos,
    );

    const can_place = circuit.main_circuit.canPlacePin(
        grid_pos,
        circuit.placement_rotation,
        null,
    );
    const render_type = if (can_place)
        ElementRenderType.holding
    else
        ElementRenderType.unable_to_place;

    var buff: [256]u8 = undefined;
    const label = std.fmt.bufPrint(
        &buff,
        "P{}",
        .{circuit.pin_counter},
    ) catch @panic("Invalid fmt");

    try renderer.renderPin(
        vector_renderer,
        grid_pos,
        circuit.placement_rotation,
        label,
        render_type,
    );
}

fn screenToWorld(
    viewport: dvui.Rect.Physical,
    pos: dvui.Point.Physical,
    zoom: f32,
) circuit.GridSubposition {
    const viewport_pos = pos.diff(viewport.topLeft()).diff(.{ .x = -camera_x, .y = -camera_y });
    const scaled_grid_size = VectorRenderer.grid_cell_px_size * zoom;
    return circuit.GridSubposition{
        .x = viewport_pos.x / scaled_grid_size,
        .y = viewport_pos.y / scaled_grid_size,
    };
}

fn adjustCameraForZoom(
    viewport: dvui.Rect.Physical,
    pos: dvui.Point.Physical,
    prev_zoom: f32,
    new_zoom: f32,
) void {
    const new_grid_size = VectorRenderer.grid_cell_px_size * new_zoom;
    const prev_pos = screenToWorld(viewport, pos, prev_zoom);
    const new_pos = screenToWorld(viewport, pos, new_zoom);

    camera_x += (prev_pos.x - new_pos.x) * new_grid_size;
    camera_y += (prev_pos.y - new_pos.y) * new_grid_size;
}

pub fn nearestGridPosition(
    circuit_rect: dvui.Rect.Physical,
    pos: dvui.Point.Physical,
) circuit.GridPosition {
    const rel_pos = pos.diff(circuit_rect.topLeft()).diff(.{ .x = -camera_x, .y = -camera_y });
    const grid_size = VectorRenderer.grid_cell_px_size * zoom_scale;

    const grid_pos = circuit.GridPosition{
        .x = @intFromFloat(@floor(rel_pos.x / grid_size + 0.5)),
        .y = @intFromFloat(@floor(rel_pos.y / grid_size + 0.5)),
    };

    return grid_pos;
}

fn renderGrid(
    vector_renderer: *const VectorRenderer,
) !void {
    const grid_color = comptime dvui.Color.fromHSLuv(200, 5, 30, 50);
    const grid_instructions = [_]VectorRenderer.BrushInstruction{
        .{ .move_rel = .{ .x = 1, .y = 0 } },
        .{ .stroke = .{ .base_thickness = 1 } },
    };
    const first_grid_col = @ceil(vector_renderer.world_left);
    const last_grid_col = @floor(vector_renderer.world_right);
    var col = first_grid_col;
    while (col <= last_grid_col) : (col += 1) {
        try vector_renderer.render(
            &grid_instructions,
            .{
                .rotate = std.math.pi / 2.0,
                .scale = .both(vector_renderer.world_bottom - vector_renderer.world_top),
                .translate = .{ .x = col, .y = vector_renderer.world_top },
                .line_scale = 1,
            },
            .{ .stroke_color = grid_color },
        );
    }

    const first_grid_row = @ceil(vector_renderer.world_top);
    const last_grid_row = @floor(vector_renderer.world_bottom);
    var row = first_grid_row;
    while (row <= last_grid_row) : (row += 1) {
        try vector_renderer.render(
            &grid_instructions,
            .{
                .rotate = 0,
                .scale = .both(vector_renderer.world_right - vector_renderer.world_left),
                .translate = .{ .x = vector_renderer.world_left, .y = row },
                .line_scale = 1,
            },
            .{ .stroke_color = grid_color },
        );
    }
}
pub fn renderPlacement(vector_renderer: *const VectorRenderer) !void {
    std.debug.assert(vector_renderer.output == .screen);
    const viewport = vector_renderer.output.screen.viewport;

    switch (circuit.placement_mode) {
        .none => {},
        .new_component => |data| try renderHoldingComponent(
            data.device_type,
            vector_renderer,
            null,
        ),
        .new_wire => |data| try renderHoldingWire(vector_renderer, data.held_wire_p1),
        .new_pin => try renderHoldingPin(vector_renderer),
        .new_ground => try renderHoldingGround(vector_renderer, null),
        .dragging_ground => |data| try renderHoldingGround(vector_renderer, data.ground_id),
        .dragging_component => |data| {
            const graphic_comp = circuit.main_circuit.graphic_components.items[data.comp_id];
            const dev_type = graphic_comp.comp.device;
            try renderHoldingComponent(dev_type, vector_renderer, data.comp_id);
        },
        .dragging_wire => |data| {
            const wire = circuit.main_circuit.wires.items[data.wire_id];
            const m_grid_pos = screenToWorld(viewport, mouse_pos, zoom_scale);
            const adjusted_pos: circuit.GridSubposition = switch (wire.direction) {
                .vertical => .{
                    .x = m_grid_pos.x,
                    .y = m_grid_pos.y - data.offset,
                },
                .horizontal => .{
                    .x = m_grid_pos.x - data.offset,
                    .y = m_grid_pos.y,
                },
            };

            const pos: circuit.GridPosition = .{
                .x = @intFromFloat(@round(adjusted_pos.x)),
                .y = @intFromFloat(@round(adjusted_pos.y)),
            };

            const new_wire = circuit.Wire{
                .direction = wire.direction,
                .length = wire.length,
                .pos = pos,
            };

            const can_place = circuit.main_circuit.canPlaceWire(new_wire, data.wire_id);
            const render_type = if (can_place)
                ElementRenderType.holding
            else
                ElementRenderType.unable_to_place;

            try renderer.renderWire(vector_renderer, new_wire, render_type, &circuit.main_circuit.junctions);
        },
        .dragging_pin => |data| {
            const pin = circuit.main_circuit.pins.items[data.pin_id];
            const pos = nearestGridPosition(viewport, mouse_pos);
            const can_place = circuit.main_circuit.canPlacePin(
                pos,
                circuit.placement_rotation,
                null,
            );

            const render_type = if (can_place)
                ElementRenderType.holding
            else
                ElementRenderType.unable_to_place;

            try renderer.renderPin(
                vector_renderer,
                pos,
                circuit.placement_rotation,
                pin.name,
                render_type,
            );
        },
    }
}
pub fn renderCircuit(allocator: std.mem.Allocator) !void {
    var circuit_area = dvui.widgetAlloc(dvui.BoxWidget);
    circuit_area.init(@src(), .{
        .dir = .horizontal,
    }, .{
        .color_fill = dvui.themeGet().color(.content, .fill),
        .background = true,
        .expand = .both,
    });
    circuit_area.data().was_allocated_on_widget_stack = true;
    defer circuit_area.deinit();

    circuit_area.drawBackground();
    try handleCircuitAreaEvents(allocator, circuit_area);

    const circuit_rect = circuit_area.data().rectScale().r;

    // TODO: optimize this
    var grid_positions = std.ArrayList(circuit.GridPosition){};
    defer grid_positions.deinit(allocator);

    for (circuit.main_circuit.graphic_components.items, 0..) |graphic_comp, i| {
        switch (circuit.placement_mode) {
            .dragging_component => |data| {
                if (data.comp_id == i) continue;
            },
            else => {},
        }
        // TODO
        var buff: [100]component.OccupiedGridPosition = undefined;
        const occupied_positions = graphic_comp.getOccupiedGridPositions(buff[0..]);
        for (occupied_positions) |occupied_pos| {
            try grid_positions.append(allocator, occupied_pos.pos);
        }
    }

    for (circuit.main_circuit.wires.items, 0..) |wire, i| {
        switch (circuit.placement_mode) {
            .dragging_wire => |data| {
                if (data.wire_id == i) continue;
            },
            else => {},
        }
        var it = wire.iterator();
        while (it.next()) |pos| {
            try grid_positions.append(allocator, pos);
        }
    }

    // TODO
    // TODO
    // TODO
    // TODO
    const hovered_component_id: ?usize = blk: switch (circuit.placement_mode) {
        .none => |data| if (data.hovered_element) |element| {
            break :blk switch (element) {
                .component => |comp_id| comp_id,
                else => null,
            };
        } else break :blk null,
        else => null,
    };

    const selected_component_id: ?usize = if (circuit.selection) |element| blk: {
        break :blk switch (element) {
            .component => |comp_id| comp_id,
            else => null,
        };
    } else null;

    const hovered_wire_id: ?usize = blk: switch (circuit.placement_mode) {
        .none => |data| if (data.hovered_element) |element| {
            break :blk switch (element) {
                .wire => |wire_id| wire_id,
                else => null,
            };
        } else break :blk null,
        else => null,
    };

    const selected_wire_id: ?usize = if (circuit.selection) |element| blk: {
        break :blk switch (element) {
            .wire => |wire_id| wire_id,
            else => null,
        };
    } else null;

    const hovered_pin_id: ?usize = blk: switch (circuit.placement_mode) {
        .none => |data| if (data.hovered_element) |element| {
            break :blk switch (element) {
                .pin => |pin_id| pin_id,
                else => null,
            };
        } else break :blk null,
        else => null,
    };

    const selected_pin_id: ?usize = if (circuit.selection) |element| blk: {
        break :blk switch (element) {
            .pin => |pin_id| pin_id,
            else => null,
        };
    } else null;

    const hovered_ground_id: ?usize = blk: switch (circuit.placement_mode) {
        .none => |data| if (data.hovered_element) |element| {
            break :blk switch (element) {
                .ground => |ground_id| ground_id,
                else => null,
            };
        } else break :blk null,
        else => null,
    };

    const selected_ground_id: ?usize = if (circuit.selection) |element| blk: {
        break :blk switch (element) {
            .ground => |ground_id| ground_id,
            else => null,
        };
    } else null;

    // TODO
    // TODO
    // TODO

    try circuit.main_circuit.findJunctions();

    const grid_size = @as(f32, VectorRenderer.grid_cell_px_size) * zoom_scale;
    const world_left = camera_x / grid_size;
    const world_top = camera_y / grid_size;
    const world_right = world_left + circuit_rect.w / grid_size;
    const world_bottom = world_top + circuit_rect.h / grid_size;

    const vector_renderer = VectorRenderer.init(
        .{ .screen = .{ .viewport = circuit_rect } },
        world_top,
        world_bottom,
        world_left,
        world_right,
    );

    try renderGrid(&vector_renderer);

    for (0.., circuit.main_circuit.graphic_components.items) |i, comp| {
        switch (circuit.placement_mode) {
            .dragging_component => |data| {
                if (data.comp_id == i) continue;
            },
            else => {},
        }

        const render_type: ElementRenderType = if (i == selected_component_id)
            ElementRenderType.selected
        else if (i == hovered_component_id)
            ElementRenderType.hovered
        else
            ElementRenderType.normal;

        try comp.render(
            &vector_renderer,
            render_type,
            &circuit.main_circuit.junctions,
        );
    }

    for (circuit.main_circuit.grounds.items, 0..) |ground, i| {
        switch (circuit.placement_mode) {
            .dragging_ground => |data| {
                if (data.ground_id == i) continue;
            },
            else => {},
        }

        const render_type: ElementRenderType = if (i == selected_ground_id)
            ElementRenderType.selected
        else if (i == hovered_ground_id)
            ElementRenderType.hovered
        else
            ElementRenderType.normal;

        try renderer.renderGround(
            &vector_renderer,
            ground.pos,
            ground.rotation,
            render_type,
            &circuit.main_circuit.junctions,
        );
    }

    for (circuit.main_circuit.wires.items, 0..) |wire, i| {
        switch (circuit.placement_mode) {
            .dragging_wire => |data| {
                if (data.wire_id == i) continue;
            },
            else => {},
        }

        const render_type = if (i == selected_wire_id)
            ElementRenderType.selected
        else if (i == hovered_wire_id)
            ElementRenderType.hovered
        else
            ElementRenderType.normal;

        try renderer.renderWire(
            &vector_renderer,
            wire,
            render_type,
            &circuit.main_circuit.junctions,
        );
    }

    for (circuit.main_circuit.pins.items, 0..) |pin, i| {
        switch (circuit.placement_mode) {
            .dragging_pin => |data| {
                if (data.pin_id == i) continue;
            },
            else => {},
        }

        const render_type = if (i == selected_pin_id)
            ElementRenderType.selected
        else if (i == hovered_pin_id)
            ElementRenderType.hovered
        else
            ElementRenderType.normal;

        try renderer.renderPin(&vector_renderer, pin.pos, pin.rotation, pin.name, render_type);
    }

    try circuit.main_circuit.renderJunctions(&vector_renderer);

    try renderPlacement(&vector_renderer);

    const Cursor = dvui.enums.Cursor;

    const cursor = switch (circuit.placement_mode) {
        .none => |data| if (data.hovered_element != null) Cursor.hand else Cursor.arrow,
        .dragging_component, .dragging_wire, .dragging_pin, .dragging_ground => Cursor.arrow_all,
        .new_wire, .new_pin, .new_component, .new_ground => Cursor.arrow,
    };

    dvui.cursorSet(cursor);
}
