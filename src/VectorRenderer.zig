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
    /// Reset the path buffer
    reset,

    /// Pick up the brush and place it at an absolute position
    /// This resets the path buffer and adds the position provided to it
    place: Vector,

    /// Move brush relative to the current brush position
    move_rel: Vector,

    /// Move brush to an absolute position
    move_abs: Vector,

    /// Draw an arc around center, the points are added to the path buffer
    /// Depending on the situation using .reset before .arc might be required to avoid
    /// unwanted lines
    /// start_angle + sweep_angle must be less than 2*pi
    arc: struct {
        /// Absolute position of the center
        center: Vector,

        /// Radius of the arc
        radius: f32,

        /// Start angle, can be negative
        start_angle: f32,

        /// Sweep angle, can be negative
        sweep_angle: f32,
    },

    /// Stroke the path currently in the path buffer
    stroke: struct {
        /// Base thickness, this is scaled by the transformation provided
        base_thickness: f32,
    },

    /// Fill the path currently in the path buffer
    fill,
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
    stroke_color: ?dvui.Color,
    fill_color: ?dvui.Color,
) !void {
    comptime var brush_pos = Vector{ .x = 0, .y = 0 };
    comptime var path_buffer: [1000]Vector = undefined;
    comptime var path_buffer_len: usize = 0;

    // add initial position
    path_buffer[0] = brush_pos;
    path_buffer_len += 1;

    inline for (instructions) |instruction| {
        switch (instruction) {
            .reset => {
                path_buffer_len = 0;
            },
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
            .arc => |opts| {
                const perimeter = opts.sweep_angle * opts.radius;
                const max_diff = opts.radius / 50;
                const point_count: usize = @intFromFloat(@round(perimeter / max_diff));
                const angle_increment = opts.sweep_angle / point_count;

                inline for (0..point_count) |i| {
                    const angle = opts.start_angle + angle_increment * @as(f32, @floatFromInt(i));
                    brush_pos = .{
                        .x = opts.center.x + opts.radius * @cos(angle),
                        .y = opts.center.y + opts.radius * @sin(angle),
                    };
                    path_buffer[path_buffer_len] = brush_pos;
                    path_buffer_len += 1;
                }
            },
            .stroke => |opts| {
                const transformed_points = self.transformPoints(
                    path_buffer[0..path_buffer_len],
                    transform,
                );
                const path = dvui.Path{ .points = transformed_points };
                path.stroke(dvui.Path.StrokeOptions{
                    .color = stroke_color.?,
                    .thickness = opts.base_thickness * transform.line_scale,
                });
            },
            .fill => {
                const transformed_points = self.transformPoints(
                    path_buffer[0..path_buffer_len],
                    transform,
                );
                const path = dvui.Path{ .points = transformed_points };
                path.fillConvex(dvui.Path.FillConvexOptions{ .color = fill_color.? });
            },
        }
    }
}
inline fn transformPoints(
    self: *const VectorRenderer,
    points: []const Vector,
    transform: Transform,
) []dvui.Point.Physical {
    var transformed_points: [points.len]dvui.Point.Physical = undefined;
    inline for (0..points.len) |i| {
        const point = points[i];

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

    return &transformed_points;
}
