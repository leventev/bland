const std = @import("std");
const dvui = @import("dvui");
const bland = @import("bland");

const renderer = @import("renderer.zig");
const circuit = @import("circuit.zig");
const component = @import("component.zig");
const global = @import("global.zig");

const ElementRenderType = renderer.ElementRenderType;

var mouse_pos: dvui.Point.Physical = undefined;

pub fn initKeybinds(allocator: std.mem.Allocator) !void {
    const win = dvui.currentWindow();
    try win.keybinds.putNoClobber(allocator, "normal_mode", .{ .key = .escape });
    try win.keybinds.putNoClobber(allocator, "register_placement_mode", .{ .key = .r });
    try win.keybinds.putNoClobber(allocator, "voltage_source_placement_mode", .{ .key = .v });
    try win.keybinds.putNoClobber(allocator, "current_source_placement_mode", .{ .key = .i });
    try win.keybinds.putNoClobber(allocator, "ground_placement_mode", .{ .key = .g });
    try win.keybinds.putNoClobber(allocator, "capacitor_placement_mode", .{ .key = .c });
    try win.keybinds.putNoClobber(allocator, "inductor_placement_mode", .{ .key = .l });
    try win.keybinds.putNoClobber(allocator, "diode_placement_mode", .{ .key = .d });
    try win.keybinds.putNoClobber(allocator, "wire_placement_mode", .{ .key = .w });
    try win.keybinds.putNoClobber(allocator, "rotate", .{ .key = .t });
    try win.keybinds.putNoClobber(allocator, "open_debug_window", .{ .key = .o });
    try win.keybinds.putNoClobber(allocator, "pin_placement_mode", .{ .key = .p });
    try win.keybinds.putNoClobber(allocator, "delete", .{ .key = .delete });
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
        circuit.placement_mode = .{ .new_component = .{ .device_type = .ground } };
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

fn handleMouseEvent(gpa: std.mem.Allocator, circuit_rect: dvui.Rect.Physical, ev: dvui.Event.Mouse) !void {
    switch (circuit.placement_mode) {
        .none => |*data| {
            var hovered_comp_id: ?usize = null;

            for (circuit.main_circuit.graphic_components.items, 0..) |graphic_comp, comp_id| {
                const inside_comp: bool = graphic_comp.mouseInside(circuit_rect, ev.p);

                if (!inside_comp) continue;

                hovered_comp_id = comp_id;
                break;
            }

            var hovered_wire_id: ?usize = null;

            for (circuit.main_circuit.wires.items, 0..) |wire, wire_id| {
                const hovered = wire.hovered(circuit_rect, ev.p);

                if (!hovered) continue;
                hovered_wire_id = wire_id;
                break;
            }

            var hovered_pin_id: ?usize = null;

            for (circuit.main_circuit.pins.items, 0..) |pin, pin_id| {
                const hovered = pin.hovered(circuit_rect, ev.p);

                if (!hovered) continue;
                hovered_pin_id = pin_id;
                break;
            }

            // priority: comp > wire > pin
            data.hovered_element =
                if (hovered_comp_id) |id|
                    .{ .component = id }
                else if (hovered_wire_id) |id|
                    .{ .wire = id }
                else if (hovered_pin_id) |id|
                    .{ .pin = id }
                else
                    null;
        },
        else => {},
    }

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
                                .wire => |wire_id| {
                                    const wire = circuit.main_circuit.wires.items[wire_id];
                                    const wire_pos = wire.pos.toCircuitPosition(
                                        circuit_rect,
                                    );

                                    const offset: f32 = switch (wire.direction) {
                                        .vertical => ev.p.y - wire_pos.y,
                                        .horizontal => ev.p.x - wire_pos.x,
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
                            circuit_rect,
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

                        const adjusted_pos = switch (wire.direction) {
                            .vertical => dvui.Point.Physical{
                                .x = ev.p.x,
                                .y = ev.p.y - data.offset,
                            },
                            .horizontal => dvui.Point.Physical{
                                .x = ev.p.x - data.offset,
                                .y = ev.p.y,
                            },
                        };
                        const grid_pos = circuit.gridPositionFromPos(
                            circuit_rect,
                            adjusted_pos,
                        );

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

                        const grid_pos = circuit.gridPositionFromPos(
                            circuit_rect,
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
                        }
                    }
                },
                .dragging_component => |data| {
                    _ = data;
                    std.log.warn("unimplemented", .{});
                },
                .dragging_wire => {},
                .dragging_pin => {},
                .new_component => |data| {
                    const grid_pos = component.gridPositionFromScreenPos(
                        data.device_type,
                        circuit_rect,
                        mouse_pos,
                        circuit.placement_rotation,
                    );

                    if (circuit.main_circuit.canPlaceComponent(data.device_type, grid_pos, circuit.placement_rotation, null)) {
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
                        const p2 = circuit.gridPositionFromPos(
                            circuit_rect,
                            mouse_pos,
                        );
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
                        data.held_wire_p1 = circuit.gridPositionFromPos(
                            circuit_rect,
                            mouse_pos,
                        );
                    }
                },
                .new_pin => {
                    const grid_pos = circuit.gridPositionFromPos(
                        circuit_rect,
                        mouse_pos,
                    );

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

const GridPositionWireConnection = struct {
    end_connection: usize,
    non_end_connection: usize,
};

fn renderHoldingComponent(
    device_type: bland.Component.DeviceType,
    circuit_rect: dvui.Rect.Physical,
    exclude_comp_id: ?usize,
) void {
    const grid_pos = component.gridPositionFromScreenPos(
        device_type,
        circuit_rect,
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

    component.renderComponentHolding(
        device_type,
        circuit_rect,
        grid_pos,
        circuit.placement_rotation,
        render_type,
    );
}

fn renderHoldingWire(
    held_wire_p1: ?circuit.GridPosition,
    circuit_rect: dvui.Rect.Physical,
) void {
    const p1 = held_wire_p1 orelse return;
    const p2 = circuit.gridPositionFromPos(circuit_rect, mouse_pos);
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

    const can_place = circuit.main_circuit.canPlaceWire(wire, null);
    const render_type = if (can_place)
        ElementRenderType.holding
    else
        ElementRenderType.unable_to_place;

    renderer.renderWire(circuit_rect, wire, render_type);
}

fn renderPin(
    circuit_rect: dvui.Rect.Physical,
    grid_pos: circuit.GridPosition,
    rotation: circuit.Rotation,
    label: []const u8,
    render_type: renderer.ElementRenderType,
) void {
    // TODO: better font handling
    const f = dvui.Font{
        .id = .fromName(global.font_name),
        .size = global.circuit_font_size,
    };

    const dist_from_point = 10;
    const angle = 15.0 / 180.0 * std.math.pi;

    const color = render_type.colors().component_color;
    const thickness = render_type.thickness();

    const pos = grid_pos.toCircuitPosition(circuit_rect);

    const label_size = dvui.Font.textSize(f, label);
    const rect_width = label_size.w + 20;
    const rect_height = label_size.h + 10;

    switch (rotation) {
        .top, .bottom => {
            const trig_height = (comptime std.math.tan(angle)) * rect_width / 2;

            var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());
            defer path.deinit();

            const sign: f32 = if (rotation == .bottom) 1 else -1;

            // triangle peak
            path.addPoint(dvui.Point.Physical{
                .x = pos.x,
                .y = pos.y + dist_from_point * sign,
            });

            // rect bottom/top left
            path.addPoint(dvui.Point.Physical{
                .x = pos.x - rect_width / 2,
                .y = pos.y + (dist_from_point + trig_height) * sign,
            });

            // rect top/bottom left
            path.addPoint(dvui.Point.Physical{
                .x = pos.x - rect_width / 2,
                .y = pos.y + (dist_from_point + trig_height + rect_height) * sign,
            });

            // rect top/bottom right
            path.addPoint(dvui.Point.Physical{
                .x = pos.x + rect_width / 2,
                .y = pos.y + (dist_from_point + trig_height + rect_height) * sign,
            });

            // rect bottom/top left
            path.addPoint(dvui.Point.Physical{
                .x = pos.x + rect_width / 2,
                .y = pos.y + (dist_from_point + trig_height) * sign,
            });

            // triangle peak
            path.addPoint(dvui.Point.Physical{
                .x = pos.x,
                .y = pos.y + dist_from_point * sign,
            });

            const p = path.build();

            p.stroke(.{ .color = color, .thickness = thickness });

            renderer.renderCenteredText(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y + (dist_from_point + trig_height + rect_height / 2) * sign,
                },
                dvui.themeGet().color(.content, .text),
                label,
            );
        },
        .right, .left => {
            const trig_height = (comptime std.math.tan(angle)) * rect_height / 2;

            var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());
            defer path.deinit();

            const sign: f32 = if (rotation == .right) 1 else -1;

            // triangle peak
            path.addPoint(dvui.Point.Physical{
                .x = pos.x + dist_from_point * sign,
                .y = pos.y,
            });

            // rect bottom left/right
            path.addPoint(dvui.Point.Physical{
                .x = pos.x + (dist_from_point + trig_height) * sign,
                .y = pos.y + rect_height / 2,
            });

            // rect bottom right/left
            path.addPoint(dvui.Point.Physical{
                .x = pos.x + (dist_from_point + trig_height + rect_width) * sign,
                .y = pos.y + rect_height / 2,
            });

            // rect top right/left
            path.addPoint(dvui.Point.Physical{
                .x = pos.x + (dist_from_point + trig_height + rect_width) * sign,
                .y = pos.y - rect_height / 2,
            });

            // rect bottom left/right
            path.addPoint(dvui.Point.Physical{
                .x = pos.x + (dist_from_point + trig_height) * sign,
                .y = pos.y - rect_height / 2,
            });

            // triangle peak
            path.addPoint(dvui.Point.Physical{
                .x = pos.x + dist_from_point * sign,
                .y = pos.y,
            });

            const p = path.build();

            p.stroke(.{ .color = color, .thickness = thickness });

            renderer.renderCenteredText(
                dvui.Point.Physical{
                    .x = pos.x + (dist_from_point + trig_height + rect_width / 2) * sign,
                    .y = pos.y,
                },
                dvui.themeGet().color(.content, .text),
                label,
            );
        },
    }
}

fn renderHoldingPin(circuit_rect: dvui.Rect.Physical) void {
    const grid_pos = circuit.gridPositionFromPos(
        circuit_rect,
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

    renderPin(circuit_rect, grid_pos, circuit.placement_rotation, label, render_type);
}

pub fn renderCircuit(allocator: std.mem.Allocator) !void {
    // to decide where to render lumps we count all wire connections per node
    // it would be better to visualize this with a drawing on paper
    // if end_connection > 0 and non_end_connection > 0 then we put a lump there
    // if end_connection > 2 or non_end_connection == 2 then we put a lump there
    var grid_pos_wire_connections = std.AutoHashMap(
        circuit.GridPosition,
        GridPositionWireConnection,
    ).init(
        allocator,
    );
    defer grid_pos_wire_connections.deinit();

    var circuit_area = dvui.BoxWidget.init(@src(), .{
        .dir = .horizontal,
    }, .{
        .color_fill = dvui.themeGet().color(.content, .fill),
        .background = true,
        .expand = .both,
    });
    defer circuit_area.deinit();

    circuit_area.install();
    circuit_area.drawBackground();
    try handleCircuitAreaEvents(allocator, &circuit_area);

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

    const count_x: usize = @intFromFloat(@divTrunc(circuit_rect.w, global.grid_size) + 1);
    const count_y: usize = @intFromFloat(@divTrunc(circuit_rect.h, global.grid_size) + 1);

    for (0..count_x) |i| {
        for (0..count_y) |j| {
            var dont_render = false;
            for (grid_positions.items) |grid_pos| {
                if (grid_pos.eql(circuit.GridPosition{
                    .x = @as(i32, @intCast(i)),
                    .y = @as(i32, @intCast(j)),
                })) {
                    dont_render = true;
                    break;
                }
            }

            if (dont_render) continue;

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

    // TODO
    // TODO
    // TODO

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

        var terminal_buff: [8]circuit.GridPosition = undefined;
        const terminals = comp.terminals(&terminal_buff);
        for (terminals) |gpos| {
            // ensure key existsterm
            _ = try grid_pos_wire_connections.getOrPutValue(gpos, .{
                .end_connection = 0,
                .non_end_connection = 0,
            });
            var ptr = grid_pos_wire_connections.getPtr(gpos).?;
            ptr.end_connection += 1;
        }

        comp.render(circuit_rect, render_type);
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

        var it = wire.iterator();
        while (it.next()) |gpos| {
            // ensure key existsterm
            _ = try grid_pos_wire_connections.getOrPutValue(gpos, .{
                .end_connection = 0,
                .non_end_connection = 0,
            });
            var ptr = grid_pos_wire_connections.getPtr(gpos).?;

            if (gpos.eql(wire.pos) or gpos.eql(wire.end())) {
                ptr.end_connection += 1;
            } else {
                ptr.non_end_connection += 1;
            }
        }
        renderer.renderWire(circuit_rect, wire, render_type);
    }

    var it = grid_pos_wire_connections.iterator();
    while (it.next()) |entry| {
        const gpos = entry.key_ptr.*;
        const wire_connections = entry.value_ptr.*;

        const is_junction = wire_connections.end_connection > 0 and wire_connections.non_end_connection > 0 or
            wire_connections.end_connection > 2 or wire_connections.non_end_connection == 2;

        const is_end = wire_connections.end_connection == 1 and wire_connections.non_end_connection == 0;

        if (is_junction) {
            var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());
            defer path.deinit();

            const pos = gpos.toCircuitPosition(circuit_rect);

            path.addArc(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y,
                },
                7,
                dvui.math.pi * 2,
                0,
                false,
            );

            path.build().fillConvex(.{
                .color = ElementRenderType.normal.colors().terminal_wire_color,
            });
        } else if (is_end) {
            var path = dvui.Path.Builder.init(dvui.currentWindow().lifo());
            defer path.deinit();

            const pos = gpos.toCircuitPosition(circuit_rect);

            path.addArc(
                dvui.Point.Physical{
                    .x = pos.x,
                    .y = pos.y,
                },
                7,
                dvui.math.pi * 2,
                0,
                false,
            );

            path.build().fillConvex(.{
                .color = dvui.themeGet().fill,
            });
            path.build().stroke(.{
                .color = ElementRenderType.normal.colors().terminal_wire_color,
                .thickness = 2,
            });
        }
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

        renderPin(circuit_rect, pin.pos, pin.rotation, pin.name, render_type);
    }

    switch (circuit.placement_mode) {
        .none => {},
        .new_component => |data| renderHoldingComponent(
            data.device_type,
            circuit_rect,
            null,
        ),
        .new_wire => |data| renderHoldingWire(data.held_wire_p1, circuit_rect),
        .new_pin => renderHoldingPin(circuit_rect),
        .dragging_component => |data| {
            const graphic_comp = circuit.main_circuit.graphic_components.items[data.comp_id];
            const dev_type = graphic_comp.comp.device;
            renderHoldingComponent(dev_type, circuit_rect, data.comp_id);
        },
        .dragging_wire => |data| {
            const wire = circuit.main_circuit.wires.items[data.wire_id];

            const adjusted_pos = switch (wire.direction) {
                .vertical => dvui.Point.Physical{
                    .x = mouse_pos.x,
                    .y = mouse_pos.y - data.offset,
                },
                .horizontal => dvui.Point.Physical{
                    .x = mouse_pos.x - data.offset,
                    .y = mouse_pos.y,
                },
            };

            const pos = circuit.gridPositionFromPos(circuit_rect, adjusted_pos);

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

            renderer.renderWire(circuit_rect, new_wire, render_type);
        },
        .dragging_pin => |data| {
            const pin = circuit.main_circuit.pins.items[data.pin_id];
            const pos = circuit.gridPositionFromPos(circuit_rect, mouse_pos);
            const can_place = circuit.main_circuit.canPlacePin(
                pos,
                circuit.placement_rotation,
                null,
            );

            const render_type = if (can_place)
                ElementRenderType.holding
            else
                ElementRenderType.unable_to_place;

            renderPin(
                circuit_rect,
                pos,
                circuit.placement_rotation,
                pin.name,
                render_type,
            );
        },
    }

    if (circuit.placement_mode == .new_component) {} else if (circuit.placement_mode == .new_wire) {}

    const Cursor = dvui.enums.Cursor;

    const cursor = switch (circuit.placement_mode) {
        .none => |data| if (data.hovered_element != null) Cursor.hand else Cursor.arrow,
        .dragging_component, .dragging_wire, .dragging_pin => Cursor.arrow_all,
        .new_component => Cursor.arrow,
        .new_wire, .new_pin => Cursor.arrow,
    };

    dvui.cursorSet(cursor);
}
