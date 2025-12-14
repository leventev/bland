const std = @import("std");
const circuit = @import("circuit.zig");
const component = @import("component.zig");
const renderer = @import("renderer.zig");
const VectorRenderer = @import("VectorRenderer.zig");
const bland = @import("bland");
const dvui = @import("dvui");
const global = @import("global.zig");

const GridPosition = circuit.GridPosition;
const GridSubposition = circuit.GridSubposition;
const Rotation = circuit.Rotation;
const ElementRenderType = renderer.ElementRenderType;
const GraphicCircuit = circuit.GraphicCircuit;

const max_pin_name_lengh = bland.component.max_component_name_length;

pub var pin_counter: usize = 1;

const Pin = @This();

pos: GridPosition,
rotation: Rotation,
name_buffer: []u8,
// name is a slice into name_buffer
name: []const u8,

pub fn init(gpa: std.mem.Allocator, pos: GridPosition, rotation: Rotation) !Pin {
    var pin = Pin{
        .pos = pos,
        .rotation = rotation,
        .name_buffer = try gpa.alloc(u8, max_pin_name_lengh),
        .name = &.{},
    };

    pin.name = std.fmt.bufPrint(pin.name_buffer, "P{}", .{pin_counter}) catch @panic("not possible");
    pin_counter += 1;

    return pin;
}

pub fn deinit(self: *Pin, gpa: std.mem.Allocator) void {
    gpa.free(self.name_buffer);
}

pub fn hovered(
    self: Pin,
    mouse_pos: GridSubposition,
    zoom: f32,
) bool {
    const f = dvui.Font{
        .id = .fromName(global.font_name),
        .size = global.circuit_font_size * zoom,
    };

    const label_size = dvui.Font.textSize(f, self.name);
    const grid_size = VectorRenderer.grid_cell_px_size * zoom;

    const rect_width = label_size.w / grid_size + padding;
    const rect_height = label_size.h / grid_size + padding;

    switch (self.rotation) {
        .right, .left => {
            const triangle_len = (rect_height / 2) * std.math.atan(angle);
            const shape = component.GraphicComponent.ClickableShape{
                .rect = .{
                    .x = gap,
                    .y = -rect_height / 2,
                    .width = triangle_len + rect_width,
                    .height = rect_height,
                },
            };

            return shape.inside(self.pos, self.rotation, zoom, mouse_pos);
        },
        .top, .bottom => {
            const triangle_len = (rect_width / 2) * std.math.atan(angle);
            const shape = component.GraphicComponent.ClickableShape{
                .rect = .{
                    .x = gap,
                    .y = -rect_width / 2,
                    .width = triangle_len + rect_height,
                    .height = rect_width,
                },
            };

            return shape.inside(self.pos, self.rotation, zoom, mouse_pos);
        },
    }
}

pub fn render(
    self: Pin,
    vector_renderer: *const VectorRenderer,
    render_type: ElementRenderType,
) !void {
    return renderPin(vector_renderer, self.pos, self.rotation, self.name, render_type);
}

const angle: f32 = 15.0 / 180.0 * std.math.pi;
const padding = 0.2;
const gap: f32 = 0.2;

pub fn renderPin(
    vector_renderer: *const VectorRenderer,
    grid_pos: circuit.GridPosition,
    rotation: circuit.Rotation,
    label: []const u8,
    render_type: ElementRenderType,
) !void {
    const zoom = switch (vector_renderer.output) {
        .screen => |s| s.zoom,
        else => 1,
    };

    // TODO: better font handling
    const f = dvui.Font{
        .id = .fromName(global.font_name),
        .size = global.circuit_font_size * zoom,
    };

    const color = render_type.colors().component_color;
    const thickness = render_type.thickness();

    const label_size = dvui.Font.textSize(f, label);
    const grid_size = VectorRenderer.grid_cell_px_size * zoom;
    const grid_pos_f = VectorRenderer.Vector{
        .x = @floatFromInt(grid_pos.x),
        .y = @floatFromInt(grid_pos.y),
    };

    const rect_width = label_size.w / grid_size + padding;
    const rect_height = label_size.h / grid_size + padding;

    const triangle_head: []const VectorRenderer.BrushInstruction = &.{
        .{ .place = .{ .x = 1, .y = -1 } },
        .{ .move_rel = .{ .x = -1, .y = 1 } },
        .{ .move_rel = .{ .x = 1, .y = 1 } },
        .{ .stroke = .{ .base_thickness = 1 } },
    };

    const partial_rect: []const VectorRenderer.BrushInstruction = &.{
        .{ .place = .{ .x = 0, .y = -0.5 } },
        .{ .move_rel = .{ .x = 1, .y = 0 } },
        .{ .move_rel = .{ .x = 0, .y = 1 } },
        .{ .move_rel = .{ .x = -1, .y = 0 } },
        .{ .stroke = .{ .base_thickness = 1 } },
    };

    switch (rotation) {
        .left, .right => {
            const inv = rotation == .left;
            const rot: f32 = if (inv) std.math.pi else 0;
            const triangle_len = (rect_height / 2) * std.math.atan(angle);

            try vector_renderer.render(
                triangle_head,
                .{
                    .translate = .{
                        .x = grid_pos_f.x + if (inv) -gap else gap,
                        .y = grid_pos_f.y,
                    },
                    .line_scale = thickness,
                    .scale = .{
                        .x = triangle_len,
                        .y = rect_height / 2,
                    },
                    .rotate = rot,
                },
                .{ .stroke_color = color },
            );

            const x_rect_start = gap + triangle_len;
            const x_rect_off = if (inv) -x_rect_start else x_rect_start;
            try vector_renderer.render(
                partial_rect,
                .{
                    .translate = .{
                        .x = x_rect_off + grid_pos_f.x,
                        .y = grid_pos_f.y,
                    },
                    .line_scale = thickness,
                    .scale = .{
                        .x = rect_width,
                        .y = rect_height,
                    },
                    .rotate = rot,
                },
                .{ .stroke_color = color },
            );

            const x_off: f32 = (if (inv) -rect_width else 0) + padding / 2.0;
            try vector_renderer.renderText(.{
                .x = grid_pos_f.x + x_rect_off + x_off,
                .y = grid_pos_f.y - (label_size.h / 2) / grid_size,
            }, label, dvui.themeGet().color(.content, .text), null);
        },
        .top, .bottom => {
            const inv = rotation == .top;
            const rot: f32 = if (inv) -std.math.pi / 2.0 else std.math.pi / 2.0;
            const triangle_len = (rect_width / 2) * std.math.atan(angle);

            try vector_renderer.render(
                triangle_head,
                .{
                    .translate = .{
                        .x = grid_pos_f.x,
                        .y = grid_pos_f.y + if (inv) -gap else gap,
                    },
                    .line_scale = thickness,
                    .scale = .{
                        .x = triangle_len,
                        .y = rect_width / 2,
                    },
                    .rotate = rot,
                },
                .{ .stroke_color = color },
            );

            const y_rect_start = gap + triangle_len;
            const y_rect_off = if (inv) -y_rect_start else y_rect_start;
            try vector_renderer.render(
                partial_rect,
                .{
                    .translate = .{
                        .x = grid_pos_f.x,
                        .y = grid_pos_f.y + y_rect_off,
                    },
                    .line_scale = thickness,
                    .scale = .{
                        .x = rect_height,
                        .y = rect_width,
                    },
                    .rotate = rot,
                },
                .{ .stroke_color = color },
            );

            const y_off: f32 = if (inv)
                -y_rect_start - rect_height / 2 - label_size.h / grid_size / 2.0
            else
                y_rect_start + rect_height / 2 - label_size.h / grid_size / 2.0;

            try vector_renderer.renderText(.{
                .x = grid_pos_f.x - rect_width / 2 + padding / 2.0,
                .y = grid_pos_f.y + y_off,
            }, label, dvui.themeGet().color(.content, .text), null);
        },
    }
}
