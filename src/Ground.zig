const std = @import("std");
const circuit = @import("circuit.zig");
const component = @import("component.zig");
const renderer = @import("renderer.zig");
const VectorRenderer = @import("VectorRenderer.zig");

const GridPosition = circuit.GridPosition;
const GridSubposition = circuit.GridSubposition;
const Rotation = circuit.Rotation;
const ElementRenderType = renderer.ElementRenderType;
const GraphicCircuit = circuit.GraphicCircuit;

const Ground = @This();

pos: GridPosition,
rotation: Rotation,

pub fn otherPos(self: Ground) GridPosition {
    return switch (self.rotation) {
        Rotation.left => GridPosition{
            .x = self.pos.x - 1,
            .y = self.pos.y,
        },
        Rotation.right => GridPosition{
            .x = self.pos.x + 1,
            .y = self.pos.y,
        },
        Rotation.top => GridPosition{
            .x = self.pos.x,
            .y = self.pos.y - 1,
        },
        Rotation.bottom => GridPosition{
            .x = self.pos.x,
            .y = self.pos.y + 1,
        },
    };
}

pub fn hovered(
    self: Ground,
    mouse_grid_pos: GridSubposition,
    zoom: f32,
) bool {
    const shape = component.GraphicComponent.ClickableShape{
        .rect = .{
            .x = ground_wire_len,
            .y = -ground_level_1_len / 2.0,
            .width = ground_pyramide_len,
            .height = ground_level_1_len,
        },
    };

    return shape.inside(self.pos, self.rotation, zoom, mouse_grid_pos);
}

const ground_pyramide_len = 0.3;
const ground_wire_len = 0.6;
const ground_level_1_len = 0.7;
const ground_level_2_len = 0.45;
const ground_level_3_len = 0.2;
const ground_level_gap = ground_pyramide_len / 2.0;

pub fn render(
    self: Ground,
    vector_renderer: *const VectorRenderer,
    render_type: ElementRenderType,
    junctions: ?*const std.AutoHashMapUnmanaged(GridPosition, GraphicCircuit.Junction),
) !void {
    const render_colors = render_type.colors();
    const thickness = render_type.thickness();

    const bodyInstructions: []const VectorRenderer.BrushInstruction = &.{
        .{ .snap_pixel_set = true },
        .{ .place = .{ .x = ground_wire_len, .y = -ground_level_1_len / 2.0 } },
        .{ .move_rel = .{ .x = 0, .y = ground_level_1_len } },
        .{ .stroke = .{ .base_thickness = 1 } },
        .{ .reset = {} },
        .{ .place = .{ .x = ground_wire_len + ground_level_gap, .y = -ground_level_2_len / 2.0 } },
        .{ .move_rel = .{ .x = 0, .y = ground_level_2_len } },
        .{ .stroke = .{ .base_thickness = 1 } },
        .{ .reset = {} },
        .{ .place = .{ .x = ground_wire_len + 2.0 * ground_level_gap, .y = -ground_level_3_len / 2.0 } },
        .{ .move_rel = .{ .x = 0, .y = ground_level_3_len } },
        .{ .stroke = .{ .base_thickness = 1 } },
    };

    const terminalWireInstructions: []const VectorRenderer.BrushInstruction = &.{
        .{ .snap_pixel_set = true },
        .{ .move_rel = .{ .x = 1, .y = 0 } },
        .{ .stroke = .{ .base_thickness = 1 } },
    };

    const rotation: f32 = switch (self.rotation) {
        .right => 0,
        .bottom => std.math.pi / 2.0,
        .left => std.math.pi,
        .top => -std.math.pi / 2.0,
    };

    var x: f32 = @floatFromInt(self.pos.x);
    var y: f32 = @floatFromInt(self.pos.y);
    try vector_renderer.render(
        bodyInstructions,
        .{
            .line_scale = thickness,
            .scale = .both(1),
            .rotate = rotation,
            .translate = .{
                .x = @floatFromInt(self.pos.x),
                .y = @floatFromInt(self.pos.y),
            },
        },
        .{ .stroke_color = render_colors.component_color },
    );

    var scale: f32 = ground_wire_len;
    if (junctions) |js| {
        const circle_rendered = if (js.get(self.pos)) |junction|
            junction.kind() != .none
        else
            false;

        if (circle_rendered) {
            scale -= GraphicCircuit.junction_radius;
            switch (self.rotation) {
                .right => x += GraphicCircuit.junction_radius,
                .left => x -= GraphicCircuit.junction_radius,
                .top => y -= GraphicCircuit.junction_radius,
                .bottom => y += GraphicCircuit.junction_radius,
            }
        }
    }

    const zoom_scale = switch (vector_renderer.output) {
        .screen => |s| s.zoom,
        else => 1,
    };

    try vector_renderer.render(
        terminalWireInstructions,
        .{
            .line_scale = thickness * zoom_scale,
            .scale = .both(scale),
            .rotate = rotation,
            .translate = .{ .x = x, .y = y },
        },
        .{ .stroke_color = render_colors.terminal_wire_color },
    );
}
