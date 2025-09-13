const std = @import("std");
const dvui = @import("dvui");

const renderer = @import("renderer.zig");
const circuit = @import("circuit.zig");
const component = @import("component.zig");
const global = @import("global.zig");
const sidebar = @import("sidebar.zig");

const ComponentRenderType = renderer.ComponentRenderType;

var mouse_pos: dvui.Point.Physical = undefined;

fn handleCircuitAreaEvents(allocator: std.mem.Allocator, circuit_area: *dvui.BoxWidget) !void {
    for (dvui.events()) |*ev| {
        if (!circuit_area.matchEvent(ev)) continue;

        switch (ev.evt) {
            .mouse => |mouse_ev| {
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
                                const p2 = circuit.held_component.gridPositionFromScreenPos(
                                    circuit_rect,
                                    mouse_pos,
                                    circuit.held_component_rotation,
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
                                circuit.held_wire_p1 = circuit.held_component.gridPositionFromScreenPos(
                                    circuit_rect,
                                    mouse_pos,
                                    circuit.held_component_rotation,
                                );
                            }
                        }
                    },
                    else => {},
                }
            },
            .key => {},
            .text => {},
        }
    }
}

pub fn renderCircuit(allocator: std.mem.Allocator) !void {
    var circuit_area = dvui.BoxWidget.init(@src(), .{
        .dir = .horizontal,
    }, .{
        .color_fill = dvui.themeGet().color(.control, .fill),
        .expand = .both,
    });
    defer circuit_area.deinit();

    circuit_area.install();
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

        comp.render(circuit_rect, render_type);
    }

    for (circuit.wires.items) |wire| {
        renderer.renderWire(circuit_rect, wire, .normal);
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
