const std = @import("std");
const dvui = @import("dvui");

const VectorRenderer = @This();

viewport: dvui.Rect.Physical,

world_top: f32,
world_bottom: f32,
world_right: f32,
world_left: f32,

/// This is called only once per frame, since the viewport rect is
/// provided by dvui at the start of each frame
pub fn init(
    viewport: dvui.Rect.Physical,
    world_top: f32,
    world_bottom: f32,
    world_left: f32,
    world_right: f32,
) VectorRenderer {
    return VectorRenderer{
        .viewport = viewport,
        .world_top = world_top,
        .world_bottom = world_bottom,
        .world_left = world_left,
        .world_right = world_right,
    };
}

/// One unit is equal to one cell's side length in the grid
pub const Vector = struct { x: f32, y: f32 };

/// Instructions for the brush, they are chained together and executed sequentially
/// to draw shapes
pub const BrushInstruction = union(enum) {
    /// Pick up the brush and place it at an absolute position
    place: Vector,

    /// Move brush relative to the current position
    move_rel: Vector,

    /// Move brush to an absolute position
    move_abs: Vector,

    /// Stroke the path currently in the path buffer then reset the buffer
    /// and add the current brush position.
    stroke: struct {
        /// Base thickness, this is scaled by the transformation provided
        base_thickness: f32,
    },
};

/// Transformation used on the points described by a sequency of BrushInstructions
/// The sequency of transformations is: scale -> rotate -> translate
pub const Transform = struct {
    /// Translation, the coordinates are added to the points
    translate: Vector,

    /// Clockwise rotation, in radians
    rotate: f32,

    /// Scale factor, the coordinates of the points are multiplied by it
    /// Scaling by zero or negative numbers is not allowed
    scale: f32,

    /// Scale factor for line thicknesses
    line_scale: f32,
};

/// The default size of a grid cell with Transform.scale = 1 in pixels
pub const grid_cell_px_size = 64;

/// Execute a sequency of brush instructions and apply a transformation on the points.
/// Move instructions move the brush and add the new brush position to the path buffer.
/// Stroke instructions consume the path buffer, transform the points into screen
/// pixels then resets the path buffer and adds the brush position to it
pub fn render(
    self: *const VectorRenderer,
    comptime instructions: []const BrushInstruction,
    transform: Transform,
    color: dvui.Color,
) !void {
    comptime var brush_pos = Vector{ .x = 0, .y = 0 };
    comptime var path_buffer: [100]Vector = undefined;
    comptime var path_buffer_len = 0;

    // add initial position
    path_buffer[0] = brush_pos;
    path_buffer_len += 1;

    inline for (instructions) |instruction| {
        switch (instruction) {
            .place => |abs_pos| {
                brush_pos = abs_pos;
                path_buffer_len = 1;
                path_buffer[0] = brush_pos;
            },
            .move_rel => |rel_pos| {
                brush_pos = .{
                    .x = brush_pos.x + rel_pos.x,
                    .y = brush_pos.y + rel_pos.y,
                };
                path_buffer[path_buffer_len] = brush_pos;
                path_buffer_len += 1;
            },
            .move_abs => |abs_pos| {
                path_buffer[path_buffer_len] = abs_pos;
                path_buffer_len += 1;
            },
            .stroke => |opts| {
                var transformed_points: [path_buffer_len]dvui.Point.Physical = undefined;
                inline for (0..path_buffer_len) |i| {
                    const point = path_buffer[i];

                    const scaled = Vector{
                        .x = point.x * transform.scale,
                        .y = point.y * transform.scale,
                    };

                    const rot_cos = @cos(transform.rotate);
                    const rot_sin = @sin(transform.rotate);
                    const rotated = Vector{
                        .x = scaled.x * rot_cos - scaled.y * rot_sin,
                        .y = scaled.x * rot_sin + scaled.y * rot_cos,
                    };

                    const translated = Vector{
                        .x = rotated.x + transform.translate.x,
                        .y = rotated.y + transform.translate.y,
                    };

                    // from world to viewport
                    const world_width = self.world_right - self.world_left;
                    const world_height = self.world_bottom - self.world_top;

                    const xscale = self.viewport.w / world_width;
                    const yscale = self.viewport.h / world_height;
                    const viewport_pos = dvui.Point.Physical{
                        .x = (translated.x - self.world_left) * xscale,
                        .y = (translated.y - self.world_top) * yscale,
                    };

                    // from viewport to screen
                    const screen_pos = dvui.Point.Physical{
                        .x = viewport_pos.x + self.viewport.x,
                        .y = viewport_pos.y + self.viewport.y,
                    };

                    transformed_points[i] = screen_pos;
                }

                const path = dvui.Path{ .points = &transformed_points };
                path.stroke(dvui.Path.StrokeOptions{
                    .color = color,
                    .thickness = opts.base_thickness * transform.line_scale,
                });

                // reset path buffer
                path_buffer_len = 1;
                path_buffer[0] = brush_pos;
            },
        }
    }
}
