const std = @import("std");
const circuit = @import("circuit.zig");
const VectorRenderer = @import("VectorRenderer.zig");
const renderer = @import("renderer.zig");

const GraphicCircuit = circuit.GraphicCircuit;
const GridPosition = circuit.GridPosition;

pub fn exportToSVG(graphic_circuit: *const GraphicCircuit) !void {
    if (graphic_circuit.graphic_components.items.len < 1) return;

    var x_min: i32 = std.math.maxInt(i32);
    var y_min: i32 = std.math.maxInt(i32);
    var x_max: i32 = std.math.minInt(i32);
    var y_max: i32 = std.math.minInt(i32);

    for (graphic_circuit.graphic_components.items[0..]) |comp| {
        var terminal_buff: [8]GridPosition = undefined;
        const terminals = comp.terminals(&terminal_buff);

        for (terminals) |term| {
            x_min = @min(x_min, term.x);
            y_min = @min(y_min, term.y);
            x_max = @max(x_max, term.x);
            y_max = @max(y_max, term.y);
        }
    }

    for (graphic_circuit.wires.items) |wire| {
        const end = wire.end();

        x_min = @min(x_min, wire.pos.x, end.x);
        y_min = @min(y_min, wire.pos.y, end.y);
        x_max = @max(x_max, wire.pos.x, end.x);
        y_max = @max(y_max, wire.pos.y, end.y);
    }

    for (graphic_circuit.grounds.items) |ground| {
        const other_pos = ground.otherPos();

        x_min = @min(x_min, ground.pos.x, other_pos.x);
        y_min = @min(y_min, ground.pos.y, other_pos.y);
        x_max = @max(x_max, ground.pos.x, other_pos.x);
        y_max = @max(y_max, ground.pos.y, other_pos.y);
    }

    // make the bounds 1 larger so all elements will fit
    x_min -= 1;
    y_min -= 1;
    x_max += 1;
    y_max += 1;

    const x_span = x_max - x_min;
    const y_span = y_max - y_min;
    const width = @as(f32, @floatFromInt(x_span)) * VectorRenderer.grid_cell_px_size;
    const height = @as(f32, @floatFromInt(y_span)) * VectorRenderer.grid_cell_px_size;
    // TODO: 16 KiB seems enough for a component?
    const file = try std.fs.cwd().createFile("circuit.svg", .{});
    defer file.close();

    var buffer: [4 * 4096]u8 = undefined;
    var file_writer = file.writer(&buffer);
    var writer = &file_writer.interface;

    _ = try writer.print(
        "<svg width=\"{}\" height=\"{}\" xmlns=\"http://www.w3.org/2000/svg\">\n",
        .{ width, height },
    );

    var vector_renderer = VectorRenderer.init(
        .{ .svg_export = .{
            .writer = writer,
            .canvas_width = width,
            .canvas_height = height,
        } },
        @floatFromInt(y_min),
        @floatFromInt(y_max),
        @floatFromInt(x_min),
        @floatFromInt(x_max),
    );
    for (graphic_circuit.graphic_components.items) |comp| {
        try comp.render(&vector_renderer, .normal, &graphic_circuit.junctions);
        try writer.flush();
    }

    for (graphic_circuit.wires.items) |wire| {
        try renderer.renderWire(&vector_renderer, wire, .normal);
        try writer.flush();
    }

    for (graphic_circuit.grounds.items) |ground| {
        try renderer.renderGround(&vector_renderer, ground.pos, ground.rotation, .normal);
        try writer.flush();
    }

    try graphic_circuit.renderJunctions(&vector_renderer);

    _ = try writer.write("</svg>");
    try writer.flush();
}
