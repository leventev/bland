const std = @import("std");
const dvui = @import("dvui");
const global = @import("global.zig");

const VectorRenderer = @This();

output: Output,
world_top: f32,
world_bottom: f32,
world_right: f32,
world_left: f32,

pub const Output = union(enum) {
    screen: struct {
        viewport: dvui.Rect.Physical,
        zoom: f32,
    },
    svg_export: struct {
        canvas_width: f32,
        canvas_height: f32,
        writer: *std.Io.Writer,
    },
};

/// This is called only once per frame, since the viewport rect is
/// provided by dvui at the start of each frame
pub fn init(
    output: Output,
    world_top: f32,
    world_bottom: f32,
    world_left: f32,
    world_right: f32,
) VectorRenderer {
    return VectorRenderer{
        .output = output,
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

    /// Snap points to the nearest whole pixel
    /// Useful for straight lines, not recommended for arcs
    snap_pixel_set: bool,
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
    scale: Scale,

    /// Scale factor for line thicknesses
    line_scale: f32,

    /// Scaling factor for both axis
    pub const Scale = struct {
        x: f32,
        y: f32,

        pub fn both(s: f32) Scale {
            return Scale{
                .x = s,
                .y = s,
            };
        }
    };
};

pub const RenderOptions = struct {
    stroke_color: ?dvui.Color = null,

    fill_color: ?dvui.Color = null,
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
    render_opts: RenderOptions,
) !void {
    @setEvalBranchQuota(10_000);

    const path_buffer_cap = 1000;
    comptime var brush_pos = Vector{ .x = 0, .y = 0 };
    comptime var path_buffer: [path_buffer_cap]Vector = undefined;
    comptime var snap_points: [path_buffer_cap]bool = undefined;
    comptime var path_buffer_len: usize = 0;
    comptime var snap_enabled = false;

    // add initial position
    path_buffer[0] = brush_pos;
    path_buffer_len += 1;
    snap_points[0] = snap_enabled;

    inline for (instructions) |instruction| {
        switch (instruction) {
            .reset => {
                path_buffer_len = 0;
            },
            .place => |abs_pos| {
                brush_pos = abs_pos;
                path_buffer_len = 1;
                path_buffer[0] = brush_pos;
                snap_points[0] = snap_enabled;
            },
            .move_rel => |rel_pos| {
                brush_pos = .{
                    .x = brush_pos.x + rel_pos.x,
                    .y = brush_pos.y + rel_pos.y,
                };
                path_buffer[path_buffer_len] = brush_pos;
                snap_points[path_buffer_len] = snap_enabled;
                path_buffer_len += 1;
            },
            .move_abs => |abs_pos| {
                path_buffer[path_buffer_len] = abs_pos;
                snap_points[path_buffer_len] = snap_enabled;
                path_buffer_len += 1;
            },
            .arc => |opts| {
                const perimeter = @abs(opts.sweep_angle) * opts.radius;
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
                    snap_points[path_buffer_len] = snap_enabled;
                    path_buffer_len += 1;
                }
            },
            .stroke => |opts| {
                switch (self.output) {
                    .screen => |screen_opts| {
                        _ = screen_opts;
                        const screen_points = self.transformPoints(
                            path_buffer[0..path_buffer_len],
                            snap_points[0..path_buffer_len],
                            transform,
                        );
                        const path = dvui.Path{ .points = screen_points };
                        path.stroke(dvui.Path.StrokeOptions{
                            .color = render_opts.stroke_color.?,
                            .thickness = opts.base_thickness * transform.line_scale,
                        });
                    },
                    .svg_export => |export_opts| {
                        const svg_points = self.transformPoints(
                            path_buffer[0..path_buffer_len],
                            null,
                            transform,
                        );

                        var writer = export_opts.writer;
                        _ = try writer.write("<polyline points=\"");

                        for (svg_points, 0..) |point, i| {
                            _ = try writer.print("{},{}", .{ point.x, point.y });
                            if (i < svg_points.len - 1) {
                                _ = try writer.write(" ");
                            }
                        }

                        _ = try writer.write("\" style=\"fill:none;stroke:black;stroke-width:1;stroke-linecap:round\"/>\n");
                    },
                }
            },
            .fill => {
                switch (self.output) {
                    .screen => |screen_opts| {
                        _ = screen_opts;
                        const screen_points = self.transformPoints(
                            path_buffer[0..path_buffer_len],
                            snap_points[0..path_buffer_len],
                            transform,
                        );
                        const path = dvui.Path{ .points = screen_points };
                        path.fillConvex(dvui.Path.FillConvexOptions{ .color = render_opts.fill_color.? });
                    },
                    .svg_export => |export_opts| {
                        const svg_points = self.transformPoints(
                            path_buffer[0..path_buffer_len],
                            null,
                            transform,
                        );

                        var writer = export_opts.writer;
                        _ = try writer.write("<polyline points=\"");

                        for (svg_points, 0..) |point, i| {
                            _ = try writer.print("{},{}", .{ point.x, point.y });
                            if (i < svg_points.len - 1) {
                                _ = try writer.write(" ");
                            }
                        }

                        _ = try writer.write("\" style=\"fill:black\"/>\n");
                    },
                }
            },
            .snap_pixel_set => |enabled| snap_enabled = enabled,
        }
    }
}

fn viewport(self: *const VectorRenderer) dvui.Rect.Physical {
    return switch (self.output) {
        .screen => |s| s.viewport,
        .svg_export => |s| .{
            .x = 0,
            .y = 0,
            .w = s.canvas_width,
            .h = s.canvas_height,
        },
    };
}

pub fn renderText(
    self: *const VectorRenderer,
    pos: Vector,
    text: []const u8,
    fg_color: dvui.Color,
    bg_color: ?dvui.Color,
) !void {
    const screen_pos = self.worldToScreen(pos);
    switch (self.output) {
        .screen => |screen_opts| {
            const f = dvui.Font{
                .id = .fromName(global.font_name),
                .size = global.circuit_font_size * screen_opts.zoom,
                .line_height_factor = 1,
            };

            const s = dvui.Font.textSize(f, text);

            const r = dvui.Rect.Physical{
                .x = screen_pos.x,
                .y = screen_pos.y,
                .w = s.w,
                .h = s.h,
            };

            dvui.renderText(.{
                .font = f,
                .text = text,
                .color = fg_color,
                .background_color = bg_color,
                .rs = .{ .r = r },
            }) catch @panic("Failed to render text");
        },
        .svg_export => @panic("TODO"),
    }
}

inline fn worldToScreen(
    self: *const VectorRenderer,
    world_pos: Vector,
) dvui.Point.Physical {
    const vp = self.viewport();

    // from world to viewport
    const world_width = self.world_right - self.world_left;
    const world_height = self.world_bottom - self.world_top;

    const xscale = vp.w / world_width;
    const yscale = vp.h / world_height;
    const viewport_pos = dvui.Point.Physical{
        .x = (world_pos.x - self.world_left) * xscale,
        .y = (world_pos.y - self.world_top) * yscale,
    };

    // from viewport to screen
    return dvui.Point.Physical{
        .x = viewport_pos.x + vp.x,
        .y = viewport_pos.y + vp.y,
    };
}

inline fn transformPoints(
    self: *const VectorRenderer,
    comptime points: []const Vector,
    comptime snap_points: ?[]bool,
    transform: Transform,
) []dvui.Point.Physical {
    var transformed_points: [points.len]dvui.Point.Physical = undefined;
    inline for (0..points.len) |i| {
        const point = points[i];

        const scaled = Vector{
            .x = point.x * transform.scale.x,
            .y = point.y * transform.scale.y,
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

        const screen_pos = self.worldToScreen(translated);

        const final_screen_pos = if (snap_points) |snap_pts|
            if (snap_pts[i])
                dvui.Point.Physical{
                    .x = @round(screen_pos.x),
                    .y = @round(screen_pos.y),
                }
            else
                screen_pos
        else
            screen_pos;

        transformed_points[i] = final_screen_pos;
    }

    return &transformed_points;
}
