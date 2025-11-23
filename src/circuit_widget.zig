const std = @import("std");
const dvui = @import("dvui");
const bland = @import("bland");

const renderer = @import("renderer.zig");
const circuit = @import("circuit.zig");
const component = @import("component.zig");
const global = @import("global.zig");
const sidebar = @import("sidebar.zig");

const ComponentRenderType = renderer.ComponentRenderType;

var mouse_pos: dvui.Point.Physical = undefined;

// TODO: be able to rename pins
const Pin = struct {
    pos: circuit.GridPosition,
    rotation: circuit.Rotation,
    num: usize,
};

var pins = std.ArrayListUnmanaged(Pin){};

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
    try win.keybinds.putNoClobber(allocator, "analyse", .{ .key = .a });
    try win.keybinds.putNoClobber(allocator, "open_debug_window", .{ .key = .o });
    try win.keybinds.putNoClobber(allocator, "pin_placement_mode", .{ .key = .p });
}

fn checkForKeybinds(ev: dvui.Event.Key) !void {
    if (ev.matchBind("normal_mode") and ev.action == .down) {
        circuit.placement_mode = .none;
    }

    if (ev.matchBind("register_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .component;
        circuit.held_component = .resistor;
    }

    if (ev.matchBind("voltage_source_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .component;
        circuit.held_component = .voltage_source;
    }

    if (ev.matchBind("current_source_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .component;
        circuit.held_component = .current_source;
    }

    if (ev.matchBind("ground_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .component;
        circuit.held_component = .ground;
    }

    if (ev.matchBind("capacitor_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .component;
        circuit.held_component = .capacitor;
    }

    if (ev.matchBind("inductor_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .component;
        circuit.held_component = .inductor;
    }

    if (ev.matchBind("wire_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .wire;
        circuit.held_wire_p1 = null;
    }

    if (ev.matchBind("rotate") and ev.action == .down) {
        circuit.placement_rotation = circuit.placement_rotation.rotateClockwise();
    }

    if (ev.matchBind("analyse") and ev.action == .down) {
        circuit.main_circuit.analyseDC();
    }

    if (ev.matchBind("open_debug_window") and ev.action == .down) {
        dvui.toggleDebugWindow();
    }

    if (ev.matchBind("pin_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .pin;
    }

    if (ev.matchBind("diode_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .component;
        circuit.held_component = .diode;
    }
}

fn handleCircuitAreaEvents(allocator: std.mem.Allocator, circuit_area: *dvui.BoxWidget) !void {
    for (dvui.events()) |*ev| {
        switch (ev.evt) {
            .mouse => |mouse_ev| {
                if (!circuit_area.matchEvent(ev)) continue;
                mouse_pos = mouse_ev.p;

                const circuit_rect = circuit_area.data().rectScale().r;

                switch (mouse_ev.action) {
                    .press => {
                        if (circuit.placement_mode == .component) {
                            const grid_pos = component.gridPositionFromScreenPos(
                                circuit.held_component,
                                circuit_rect,
                                mouse_pos,
                                circuit.placement_rotation,
                            );
                            if (circuit.main_circuit.canPlaceComponent(
                                circuit.held_component,
                                grid_pos,
                                circuit.placement_rotation,
                            )) {
                                const graphic_comp = try component.GraphicComponent.init(
                                    allocator,
                                    grid_pos,
                                    circuit.placement_rotation,
                                    circuit.held_component,
                                );
                                try circuit.main_circuit.graphic_components.append(
                                    circuit.main_circuit.allocator,
                                    graphic_comp,
                                );
                            }
                        } else if (circuit.placement_mode == .wire) {
                            if (circuit.held_wire_p1) |p1| {
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

                                if (wire.length != 0 and circuit.main_circuit.canPlaceWire(wire)) {
                                    try circuit.main_circuit.wires.append(
                                        circuit.main_circuit.allocator,
                                        wire,
                                    );
                                    circuit.held_wire_p1 = null;
                                }
                            } else {
                                circuit.held_wire_p1 = circuit.gridPositionFromPos(
                                    circuit_rect,
                                    mouse_pos,
                                );
                            }
                        } else if (circuit.placement_mode == .pin) {
                            const grid_pos = circuit.gridPositionFromPos(
                                circuit_rect,
                                mouse_pos,
                            );

                            if (canPlacePin(grid_pos)) {
                                try pins.append(allocator, Pin{
                                    .pos = grid_pos,
                                    .rotation = circuit.placement_rotation,
                                    .num = pins.items.len + 1,
                                });
                            }
                        }
                    },
                    else => {},
                }
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

fn renderHoldingComponent(circuit_rect: dvui.Rect.Physical) void {
    const grid_pos = component.gridPositionFromScreenPos(
        circuit.held_component,
        circuit_rect,
        mouse_pos,
        circuit.placement_rotation,
    );

    const can_place = circuit.main_circuit.canPlaceComponent(
        circuit.held_component,
        grid_pos,
        circuit.placement_rotation,
    );
    const render_type = if (can_place)
        ComponentRenderType.holding
    else
        ComponentRenderType.unable_to_place;

    component.renderComponentHolding(
        circuit.held_component,
        circuit_rect,
        grid_pos,
        circuit.placement_rotation,
        render_type,
    );
}

fn renderHoldingWire(circuit_rect: dvui.Rect.Physical) void {
    const p1 = circuit.held_wire_p1 orelse return;
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

    const can_place = circuit.main_circuit.canPlaceWire(wire);
    const render_type = if (can_place)
        ComponentRenderType.holding
    else
        ComponentRenderType.unable_to_place;

    renderer.renderWire(circuit_rect, wire, render_type);
}

fn renderPin(
    circuit_rect: dvui.Rect.Physical,
    grid_pos: circuit.GridPosition,
    rotation: circuit.Rotation,
    label: []const u8,
    render_type: renderer.ComponentRenderType,
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
            const trig_height = std.math.tan(angle) * rect_width / 2;

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
            const trig_height = std.math.tan(angle) * rect_height / 2;

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

    const can_place = canPlacePin(grid_pos);
    const render_type = if (can_place)
        ComponentRenderType.holding
    else
        ComponentRenderType.unable_to_place;

    var buff: [256]u8 = undefined;
    const label = std.fmt.bufPrint(
        &buff,
        "Pin {}",
        .{pins.items.len + 1},
    ) catch @panic("Invalid fmt");

    renderPin(circuit_rect, grid_pos, circuit.placement_rotation, label, render_type);
}

fn canPlacePin(pos: circuit.GridPosition) bool {
    for (pins.items) |pin| {
        if (pin.pos.eql(pos)) return false;
    }

    return true;
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

    for (circuit.main_circuit.graphic_components.items) |graphic_comp| {
        // TODO
        var buff: [100]component.OccupiedGridPosition = undefined;
        const occupied_positions = graphic_comp.getOccupiedGridPositions(buff[0..]);
        for (occupied_positions) |occupied_pos| {
            try grid_positions.append(allocator, occupied_pos.pos);
        }
    }

    for (circuit.main_circuit.wires.items) |wire| {
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

    for (0.., circuit.main_circuit.graphic_components.items) |i, comp| {
        const render_type: ComponentRenderType = if (i == sidebar.selected_component_id)
            ComponentRenderType.selected
        else if (i == sidebar.hovered_component_id)
            ComponentRenderType.hovered
        else
            ComponentRenderType.normal;

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

    for (circuit.main_circuit.wires.items) |wire| {
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
        renderer.renderWire(circuit_rect, wire, .normal);
    }

    var it = grid_pos_wire_connections.iterator();
    while (it.next()) |entry| {
        const gpos = entry.key_ptr.*;
        const wire_connections = entry.value_ptr.*;
        if (wire_connections.end_connection > 0 and wire_connections.non_end_connection > 0 or
            wire_connections.end_connection > 2 or wire_connections.non_end_connection == 2)
        {
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
                .color = ComponentRenderType.normal.colors().wire_color,
            });
        }
    }

    for (pins.items) |pin| {
        var buff: [256]u8 = undefined;
        const label = try std.fmt.bufPrint(&buff, "Pin {}", .{pin.num});
        renderPin(circuit_rect, pin.pos, pin.rotation, label, .normal);
    }

    switch (circuit.placement_mode) {
        .none => {},
        .component => renderHoldingComponent(circuit_rect),
        .wire => renderHoldingWire(circuit_rect),
        .pin => renderHoldingPin(circuit_rect),
    }

    if (circuit.placement_mode == .component) {} else if (circuit.placement_mode == .wire) {}
}
