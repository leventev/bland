const std = @import("std");
const dvui = @import("dvui");

const renderer = @import("renderer.zig");
const circuit = @import("circuit.zig");
const component = @import("component.zig");
const global = @import("global.zig");
const sidebar = @import("sidebar.zig");

const ComponentRenderType = renderer.ComponentRenderType;

var mouse_pos: dvui.Point.Physical = undefined;

pub fn initKeybinds(allocator: std.mem.Allocator) !void {
    const win = dvui.currentWindow();
    try win.keybinds.putNoClobber(allocator, "normal_mode", .{ .key = .escape });
    try win.keybinds.putNoClobber(allocator, "register_placement_mode", .{ .key = .r });
    try win.keybinds.putNoClobber(allocator, "voltage_source_placement_mode", .{ .key = .v });
    try win.keybinds.putNoClobber(allocator, "ground_placement_mode", .{ .key = .g });
    try win.keybinds.putNoClobber(allocator, "wire_placement_mode", .{ .key = .w });
    try win.keybinds.putNoClobber(allocator, "rotate", .{ .key = .t });
    try win.keybinds.putNoClobber(allocator, "analyse", .{ .key = .a });
    try win.keybinds.putNoClobber(allocator, "open_debug_window", .{ .key = .l });
}

fn checkForKeybinds(allocator: std.mem.Allocator, ev: dvui.Event.Key) !void {
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

    if (ev.matchBind("ground_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .component;
        circuit.held_component = .ground;
    }

    if (ev.matchBind("wire_placement_mode") and ev.action == .down) {
        circuit.placement_mode = .wire;
        circuit.held_wire_p1 = null;
    }

    if (ev.matchBind("rotate") and ev.action == .down) {
        circuit.held_component_rotation = circuit.held_component_rotation.rotateClockwise();
    }

    if (ev.matchBind("analyse") and ev.action == .down) {
        circuit.analyse(allocator);
    }

    if (ev.matchBind("open_debug_window") and ev.action == .down) {
        dvui.toggleDebugWindow();
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
                            const grid_pos = circuit.held_component.gridPositionFromScreenPos(
                                circuit_rect,
                                mouse_pos,
                                circuit.held_component_rotation,
                            );
                            if (circuit.canPlaceComponent(
                                circuit.held_component,
                                grid_pos,
                                circuit.held_component_rotation,
                            )) {
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

                                if (wire.length != 0 and circuit.canPlaceWire(wire)) {
                                    try circuit.wires.append(wire);
                                    circuit.held_wire_p1 = null;
                                }
                            } else {
                                circuit.held_wire_p1 = circuit.gridPositionFromPos(
                                    circuit_rect,
                                    mouse_pos,
                                );
                            }
                        }
                    },
                    else => {},
                }
            },
            .key => |key_ev| {
                if (ev.target_widgetId != null) continue;
                try checkForKeybinds(allocator, key_ev);
            },
            .text => {},
        }
    }
}

const GridPositionWireConnection = struct {
    end_connection: usize,
    non_end_connection: usize,
};

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

    const count_x: usize = @intFromFloat(@divTrunc(circuit_rect.w, global.grid_size) + 1);
    const count_y: usize = @intFromFloat(@divTrunc(circuit_rect.h, global.grid_size) + 1);

    for (0..count_x) |i| {
        for (0..count_y) |j| {
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

    for (0.., circuit.components.items) |i, comp| {
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

    for (circuit.wires.items) |wire| {
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

    if (circuit.placement_mode == .component) {
        const grid_pos = circuit.held_component.gridPositionFromScreenPos(
            circuit_rect,
            mouse_pos,
            circuit.held_component_rotation,
        );

        const can_place = circuit.canPlaceComponent(
            circuit.held_component,
            grid_pos,
            circuit.held_component_rotation,
        );
        const render_type = if (can_place) ComponentRenderType.holding else ComponentRenderType.unable_to_place;
        circuit.held_component.renderHolding(
            circuit_rect,
            grid_pos,
            circuit.held_component_rotation,
            render_type,
        );
    } else if (circuit.placement_mode == .wire) {
        if (circuit.held_wire_p1) |p1| {
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

            const can_place = circuit.canPlaceWire(wire);
            const render_type = if (can_place) ComponentRenderType.holding else ComponentRenderType.unable_to_place;
            renderer.renderWire(circuit_rect, wire, render_type);
        }
    }
}
