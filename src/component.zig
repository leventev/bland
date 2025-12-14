const std = @import("std");
const dvui = @import("dvui");
const bland = @import("bland");
const circuit = @import("circuit.zig");
const global = @import("global.zig");
const renderer = @import("renderer.zig");
const VectorRenderer = @import("VectorRenderer.zig");
const circuit_widget = @import("circuit_widget.zig");
const Wire = @import("Wire.zig");

const Float = bland.Float;
const GridPosition = circuit.GridPosition;
const GridSubposition = circuit.GridSubposition;
const Rotation = circuit.Rotation;
const Component = bland.Component;
const Device = Component.Device;
const DeviceType = Component.DeviceType;

const max_component_name_length = bland.component.max_component_name_length;

const resistor_graphics_module = @import("components/resistor.zig");
const voltage_source_graphics_module = @import("components/voltage_source.zig");
const current_source_graphics_module = @import("components/current_source.zig");
const capacitor_graphics_module = @import("components/capacitor.zig");
const inductor_graphics_module = @import("components/inductor.zig");
const ccvs_graphics_module = @import("components/ccvs.zig");
const cccs_graphics_module = @import("components/cccs.zig");
const diode_graphics_module = @import("components/diode.zig");

fn graphics_module(comptime self: DeviceType) type {
    return switch (self) {
        .resistor => resistor_graphics_module,
        .voltage_source => voltage_source_graphics_module,
        .current_source => current_source_graphics_module,
        .capacitor => capacitor_graphics_module,
        .inductor => inductor_graphics_module,
        .ccvs => ccvs_graphics_module,
        .cccs => cccs_graphics_module,
        .diode => diode_graphics_module,
    };
}

pub const OccupiedGridPosition = struct {
    pos: GridPosition,
    terminal: bool,
};

pub fn occupiedPointsIntersect(
    occupied1: []const OccupiedGridPosition,
    occupied2: []const OccupiedGridPosition,
) bool {
    for (occupied1) |p1| {
        for (occupied2) |p2| {
            if (p1.pos.eql(p2.pos) and (!p1.terminal or !p2.terminal)) return true;
        }
    }
    return false;
}

fn renderDevice(
    comptime dev_type: DeviceType,
    vector_renderer: *const VectorRenderer,
    pos: GridPosition,
    rot: Rotation,
    render_type: renderer.ElementRenderType,
) !void {
    const body_instructions = switch (dev_type) {
        inline else => |x| graphics_module(x).body_instructions,
    };

    const colors = render_type.colors();
    const thickness = render_type.thickness();

    const rotation: f32 = switch (rot) {
        .right => 0,
        .bottom => std.math.pi / 2.0,
        .left => std.math.pi,
        .top => -std.math.pi / 2.0,
    };

    try vector_renderer.render(
        body_instructions,
        .{
            .translate = .{
                .x = @floatFromInt(pos.x),
                .y = @floatFromInt(pos.y),
            },
            .line_scale = thickness,
            .scale = .both(1),
            .rotate = @as(f32, @floatCast(rotation)),
        },
        .{ .stroke_color = colors.component_color },
    );
}

pub fn renderComponent(
    dev_type: DeviceType,
    vector_renderer: *const VectorRenderer,
    pos: GridPosition,
    rot: Rotation,
    render_type: renderer.ElementRenderType,
    junctions: ?*const std.AutoHashMapUnmanaged(GridPosition, circuit.GraphicCircuit.Junction),
) !void {
    switch (dev_type) {
        inline else => |x| try renderDevice(
            x,
            vector_renderer,
            pos,
            rot,
            render_type,
        ),
    }

    const colors = render_type.colors();
    const thickness = render_type.thickness();

    const rotation: f32 = switch (rot) {
        .right => 0,
        .left => -std.math.pi,
        .top => -std.math.pi / 2.0,
        .bottom => std.math.pi / 2.0,
    };

    const terminal_wires = switch (dev_type) {
        inline else => |x| graphics_module(x).terminal_wires,
    };

    const instructions: []const VectorRenderer.BrushInstruction = &.{
        .{ .move_rel = .{ .x = 1, .y = 0 } },
        .{ .stroke = .{ .base_thickness = 1 } },
    };

    for (terminal_wires) |terminal| {
        const wire_rotation: f32 = switch (terminal.direction) {
            .horizontal => 0,
            .vertical => std.math.pi / 2.0,
        };

        var rot_2 = rot;
        if (terminal.direction == .vertical) rot_2 = rot_2.rotateClockwise();
        const relative_pos_rotated: circuit.GridPosition = switch (rot_2) {
            .right => .{ .x = terminal.relative_pos.x, .y = terminal.relative_pos.y },
            .left => .{ .x = -terminal.relative_pos.x, .y = terminal.relative_pos.y },
            .bottom => .{ .x = -terminal.relative_pos.y, .y = terminal.relative_pos.x },
            .top => .{ .x = terminal.relative_pos.y, .y = -terminal.relative_pos.x },
        };
        const grid_pos = GridPosition{
            .x = pos.x + relative_pos_rotated.x,
            .y = pos.y + relative_pos_rotated.y,
        };

        var scale = terminal.len;
        const sign = std.math.sign(terminal.len);

        var line_start_pos = circuit.GridSubposition{
            .x = @floatFromInt(grid_pos.x),
            .y = @floatFromInt(grid_pos.y),
        };

        if (junctions) |js| {
            const circle_rendered = if (js.get(grid_pos)) |junction|
                junction.kind() != .none
            else
                false;

            if (circle_rendered) {
                switch (rot_2) {
                    .right => line_start_pos.x += sign * circuit.GraphicCircuit.junction_radius,
                    .left => line_start_pos.x -= sign * circuit.GraphicCircuit.junction_radius,
                    .bottom => line_start_pos.y += sign * circuit.GraphicCircuit.junction_radius,
                    .top => line_start_pos.y -= sign * circuit.GraphicCircuit.junction_radius,
                }
                scale -= sign * circuit.GraphicCircuit.junction_radius;
            }
        }

        try vector_renderer.render(
            instructions,
            .{
                .translate = .{
                    .x = line_start_pos.x,
                    .y = line_start_pos.y,
                },
                .line_scale = thickness * circuit_widget.zoom_scale,
                .scale = .both(scale),
                .rotate = rotation + wire_rotation,
            },
            .{ .stroke_color = colors.terminal_wire_color },
        );
    }
}

pub fn deviceOccupiedGridPositions(
    self: DeviceType,
    pos: GridPosition,
    rotation: Rotation,
    occupied: []OccupiedGridPosition,
) []OccupiedGridPosition {
    switch (self) {
        inline else => |x| return graphics_module(x).getOccupiedGridPositions(
            pos,
            rotation,
            occupied,
        ),
    }
}

fn deviceCenterForMouse(self: DeviceType, pos: GridPosition, rotation: Rotation) GridPosition {
    switch (self) {
        inline else => |x| return graphics_module(x).centerForMouse(
            pos,
            rotation,
        ),
    }
}

pub fn deviceGetTerminals(
    dev_type: DeviceType,
    pos: GridPosition,
    rotation: Rotation,
    terminals_buff: []GridPosition,
) []GridPosition {
    switch (dev_type) {
        inline else => |x| return graphics_module(x).getTerminals(
            pos,
            rotation,
            terminals_buff,
        ),
    }
}

pub fn gridPositionFromScreenPos(
    dev_type: DeviceType,
    circuit_rect: dvui.Rect.Physical,
    pos: dvui.Point.Physical,
    rotation: Rotation,
) GridPosition {
    const grid_pos = circuit_widget.nearestGridPosition(circuit_rect, pos);
    return deviceCenterForMouse(dev_type, grid_pos, rotation);
}

// TODO:
const max_float_length = 64;

pub const GraphicComponent = struct {
    pos: GridPosition,
    rotation: Rotation,

    comp: Component,

    // name_buffer is max_component_name_length bytes long allocated
    // comp.name is a slice into name_buffer
    name_buffer: []u8,

    value_buffer: ValueBuffer,

    pub const ClickableShape = union(enum) {
        rect: struct {
            x: f32,
            y: f32,
            width: f32,
            height: f32,
        },
        circle: struct {
            x: f32,
            y: f32,
            radius: f32,
        },

        pub fn inside(self: ClickableShape, translate: GridPosition, rotation: Rotation, zoom: f32, pos: GridSubposition) bool {
            const xf: f32 = @floatFromInt(translate.x);
            const yf: f32 = @floatFromInt(translate.y);

            const grid_size = VectorRenderer.grid_cell_px_size * zoom;
            const tolerance_px = 7;
            const tolerance = tolerance_px / grid_size;
            switch (self) {
                .rect => |r| {
                    const x1 = r.x - tolerance;
                    const y1 = r.y - tolerance;
                    const x2 = r.x + r.width + tolerance;
                    const y2 = r.y + r.height + tolerance;

                    const x1_off, const y1_off, const x2_off, const y2_off = switch (rotation) {
                        .right => .{ x1, y1, x2, y2 },
                        .left => .{ -x2, -y2, -x1, -y1 },
                        .top => .{ y1, -x2, y2, -x1 },
                        .bottom => .{ -y2, x1, -y1, x2 },
                    };
                    const rx1 = xf + x1_off;
                    const ry1 = yf + y1_off;
                    const rx2 = xf + x2_off;
                    const ry2 = yf + y2_off;
                    return pos.x > rx1 and pos.y > ry1 and pos.x < rx2 and pos.y < ry2;
                },
                .circle => |c| {
                    const rx, const ry = switch (rotation) {
                        .right => .{ c.x, c.y },
                        .left => .{ -c.x, c.y },
                        .top => .{ c.y, -c.x },
                        .bottom => .{ c.y, c.x },
                    };

                    const xd = xf + rx - pos.x;
                    const yd = yf + ry - pos.y;
                    return xd * xd + yd * yd <= c.radius * c.radius + tolerance;
                },
            }
        }
    };

    pub const Terminal = struct {
        relative_pos: GridPosition,
        direction: Wire.Direction,
        len: f32,
    };

    pub const ValueBuffer = union(Component.DeviceType) {
        resistor: struct {
            buff: []u8,
            actual: []u8,
        },
        voltage_source: struct {
            // TODO: store this smarter

            selected_function: bland.component.source.OutputFunctionType,

            // OutputFunction.dc
            dc_buff: []u8,
            dc_actual: []u8,

            // OutputFunction.phasor
            phasor_amplitude_buff: []u8,
            phasor_amplitude_actual: []u8,
            phasor_phase_buff: []u8,
            phasor_phase_actual: []u8,

            // OutputFunction.sin
            sin_amplitude_buff: []u8,
            sin_amplitude_actual: []u8,
            sin_frequency_buff: []u8,
            sin_frequency_actual: []u8,
            sin_phase_buff: []u8,
            sin_phase_actual: []u8,

            // OutputFunction.square
            square_amplitude_buff: []u8,
            square_amplitude_actual: []u8,
            square_frequency_buff: []u8,
            square_frequency_actual: []u8,
        },
        current_source: struct {
            // TODO: store this smarter

            selected_function: bland.component.source.OutputFunctionType,

            // OutputFunction.dc
            dc_buff: []u8,
            dc_actual: []u8,

            // OutputFunction.phasor
            phasor_amplitude_buff: []u8,
            phasor_amplitude_actual: []u8,
            phasor_phase_buff: []u8,
            phasor_phase_actual: []u8,

            // OutputFunction.sin
            sin_amplitude_buff: []u8,
            sin_amplitude_actual: []u8,
            sin_frequency_buff: []u8,
            sin_frequency_actual: []u8,
            sin_phase_buff: []u8,
            sin_phase_actual: []u8,

            // OutputFunction.square
            square_amplitude_buff: []u8,
            square_amplitude_actual: []u8,
            square_frequency_buff: []u8,
            square_frequency_actual: []u8,
        },
        capacitor: struct {
            buff: []u8,
            actual: []u8,
        },
        inductor: struct {
            buff: []u8,
            actual: []u8,
        },
        ccvs: struct {
            transresistance_buff: []u8,
            transresistance_actual: []u8,

            controller_name_buff: []u8,
            controller_name_actual: []u8,
        },
        cccs: struct {
            multiplier_buff: []u8,
            multiplier_actual: []u8,

            controller_name_buff: []u8,
            controller_name_actual: []u8,
        },
        diode: struct {},

        pub fn init(gpa: std.mem.Allocator, device_type: Component.DeviceType) !@This() {
            return switch (device_type) {
                .resistor => .{
                    .resistor = .{
                        .buff = try gpa.alloc(u8, max_float_length),
                        .actual = &.{},
                    },
                },
                .capacitor => .{
                    .capacitor = .{
                        .buff = try gpa.alloc(u8, max_float_length),
                        .actual = &.{},
                    },
                },
                .inductor => .{
                    .inductor = .{
                        .buff = try gpa.alloc(u8, max_float_length),
                        .actual = &.{},
                    },
                },
                .ccvs => .{
                    .ccvs = .{
                        .transresistance_buff = try gpa.alloc(u8, max_float_length),
                        .transresistance_actual = &.{},

                        .controller_name_buff = try gpa.alloc(u8, max_component_name_length),
                        .controller_name_actual = &.{},
                    },
                },
                .cccs => .{
                    .cccs = .{
                        .multiplier_buff = try gpa.alloc(u8, max_float_length),
                        .multiplier_actual = &.{},

                        .controller_name_buff = try gpa.alloc(u8, max_component_name_length),
                        .controller_name_actual = &.{},
                    },
                },
                .voltage_source => .{
                    .voltage_source = .{
                        .selected_function = .dc,

                        .dc_buff = try gpa.alloc(u8, max_float_length),
                        .dc_actual = &.{},

                        .phasor_amplitude_buff = try gpa.alloc(u8, max_float_length),
                        .phasor_amplitude_actual = &.{},
                        .phasor_phase_buff = try gpa.alloc(u8, max_float_length),
                        .phasor_phase_actual = &.{},

                        .sin_amplitude_buff = try gpa.alloc(u8, max_float_length),
                        .sin_amplitude_actual = &.{},
                        .sin_frequency_buff = try gpa.alloc(u8, max_float_length),
                        .sin_frequency_actual = &.{},
                        .sin_phase_buff = try gpa.alloc(u8, max_float_length),
                        .sin_phase_actual = &.{},

                        .square_amplitude_buff = try gpa.alloc(u8, max_float_length),
                        .square_amplitude_actual = &.{},
                        .square_frequency_buff = try gpa.alloc(u8, max_float_length),
                        .square_frequency_actual = &.{},
                    },
                },
                .current_source => .{
                    .current_source = .{
                        .selected_function = .dc,

                        .dc_buff = try gpa.alloc(u8, max_float_length),
                        .dc_actual = &.{},

                        .phasor_amplitude_buff = try gpa.alloc(u8, max_float_length),
                        .phasor_amplitude_actual = &.{},
                        .phasor_phase_buff = try gpa.alloc(u8, max_float_length),
                        .phasor_phase_actual = &.{},

                        .sin_amplitude_buff = try gpa.alloc(u8, max_float_length),
                        .sin_amplitude_actual = &.{},
                        .sin_frequency_buff = try gpa.alloc(u8, max_float_length),
                        .sin_frequency_actual = &.{},
                        .sin_phase_buff = try gpa.alloc(u8, max_float_length),
                        .sin_phase_actual = &.{},

                        .square_amplitude_buff = try gpa.alloc(u8, max_float_length),
                        .square_amplitude_actual = &.{},
                        .square_frequency_buff = try gpa.alloc(u8, max_float_length),
                        .square_frequency_actual = &.{},
                    },
                },
                .diode => .{
                    .diode = .{},
                },
            };
        }

        // TODO:
        pub fn setDefaultValue(self: *@This(), precision: usize, dev: Device) !void {
            switch (self.*) {
                .resistor => |*buf| buf.actual = try bland.units.formatPrefixBuf(
                    buf.buff,
                    dev.resistor,
                    precision,
                ),
                .capacitor => |*buf| buf.actual = try bland.units.formatPrefixBuf(
                    buf.buff,
                    dev.capacitor,
                    precision,
                ),
                .inductor => |*buf| buf.actual = try bland.units.formatPrefixBuf(
                    buf.buff,
                    dev.inductor,
                    precision,
                ),
                .ccvs => |*buf| {
                    buf.transresistance_actual = try bland.units.formatPrefixBuf(
                        buf.transresistance_buff,
                        dev.ccvs.transresistance,
                        precision,
                    );
                },
                .cccs => |*buf| {
                    buf.multiplier_actual = try bland.units.formatPrefixBuf(
                        buf.multiplier_buff,
                        dev.cccs.multiplier,
                        precision,
                    );
                },
                .voltage_source => |*buf| {
                    // TODO
                    buf.dc_actual = try bland.units.formatPrefixBuf(
                        buf.dc_buff,
                        dev.voltage_source.dc,
                        precision,
                    );

                    buf.phasor_amplitude_actual = try bland.units.formatPrefixBuf(
                        buf.phasor_amplitude_buff,
                        5,
                        precision,
                    );

                    buf.phasor_phase_actual = try bland.units.formatPrefixBuf(
                        buf.phasor_phase_buff,
                        0,
                        precision,
                    );

                    buf.sin_amplitude_actual = try bland.units.formatPrefixBuf(
                        buf.sin_amplitude_buff,
                        5,
                        precision,
                    );

                    buf.sin_frequency_actual = try bland.units.formatPrefixBuf(
                        buf.sin_frequency_buff,
                        10,
                        precision,
                    );

                    buf.sin_phase_actual = try bland.units.formatPrefixBuf(
                        buf.sin_phase_buff,
                        0,
                        precision,
                    );

                    buf.square_amplitude_actual = try bland.units.formatPrefixBuf(
                        buf.square_amplitude_buff,
                        5,
                        precision,
                    );

                    buf.square_frequency_actual = try bland.units.formatPrefixBuf(
                        buf.square_frequency_buff,
                        10,
                        precision,
                    );
                },
                .current_source => |*buf| {
                    // TODO TODO TODO
                    buf.dc_actual = try bland.units.formatPrefixBuf(
                        buf.dc_buff,
                        dev.current_source.dc,
                        precision,
                    );

                    buf.phasor_amplitude_actual = try bland.units.formatPrefixBuf(
                        buf.phasor_amplitude_buff,
                        1,
                        precision,
                    );

                    buf.phasor_phase_actual = try bland.units.formatPrefixBuf(
                        buf.phasor_phase_buff,
                        0,
                        precision,
                    );

                    buf.sin_amplitude_actual = try bland.units.formatPrefixBuf(
                        buf.sin_amplitude_buff,
                        1,
                        precision,
                    );

                    buf.sin_frequency_actual = try bland.units.formatPrefixBuf(
                        buf.sin_frequency_buff,
                        10,
                        precision,
                    );

                    buf.sin_phase_actual = try bland.units.formatPrefixBuf(
                        buf.sin_phase_buff,
                        0,
                        precision,
                    );

                    buf.square_amplitude_actual = try bland.units.formatPrefixBuf(
                        buf.square_amplitude_buff,
                        5,
                        precision,
                    );

                    buf.square_frequency_actual = try bland.units.formatPrefixBuf(
                        buf.square_frequency_buff,
                        10,
                        precision,
                    );
                },
                .diode => {},
            }
        }

        pub fn deinit(self: *@This(), gpa: std.mem.Allocator) void {
            switch (self.*) {
                .resistor => |data| {
                    gpa.free(data.buff);
                },
                .voltage_source => |data| {
                    gpa.free(data.dc_buff);
                    gpa.free(data.phasor_amplitude_buff);
                    gpa.free(data.phasor_phase_buff);
                    gpa.free(data.sin_amplitude_buff);
                    gpa.free(data.sin_frequency_buff);
                    gpa.free(data.sin_phase_buff);
                    gpa.free(data.square_amplitude_buff);
                    gpa.free(data.square_frequency_buff);
                },
                .current_source => |data| {
                    gpa.free(data.dc_buff);
                    gpa.free(data.phasor_amplitude_buff);
                    gpa.free(data.phasor_phase_buff);
                    gpa.free(data.sin_amplitude_buff);
                    gpa.free(data.sin_frequency_buff);
                    gpa.free(data.sin_phase_buff);
                    gpa.free(data.square_amplitude_buff);
                    gpa.free(data.square_frequency_buff);
                },
                .capacitor => |data| {
                    gpa.free(data.buff);
                },
                .inductor => |data| {
                    gpa.free(data.buff);
                },
                .ccvs => |data| {
                    gpa.free(data.transresistance_buff);
                    gpa.free(data.controller_name_buff);
                },
                .cccs => |data| {
                    gpa.free(data.multiplier_buff);
                    gpa.free(data.controller_name_buff);
                },
                .diode => {},
            }
        }
    };

    pub fn init(
        gpa: std.mem.Allocator,
        grid_pos: circuit.GridPosition,
        rotation: circuit.Rotation,
        device_type: DeviceType,
    ) !GraphicComponent {
        var graphic_comp = GraphicComponent{
            .pos = grid_pos,
            .rotation = rotation,
            .name_buffer = try gpa.alloc(u8, bland.component.max_component_name_length),
            .comp = bland.Component{
                .name = &.{},
                .device = try device_type.defaultValue(gpa),
                .terminal_node_ids = try gpa.alloc(bland.NetList.Node.Id, 2),
            },
            .value_buffer = try .init(gpa, device_type),
        };
        try graphic_comp.setNewComponentName();
        try graphic_comp.value_buffer.setDefaultValue(0, graphic_comp.comp.device);

        return graphic_comp;
    }

    pub fn deinit(self: *GraphicComponent, allocator: std.mem.Allocator) void {
        allocator.free(self.name_buffer);
        self.value_buffer.deinit(allocator);
    }

    pub fn terminals(self: *const GraphicComponent, buffer: []GridPosition) []GridPosition {
        return deviceGetTerminals(
            @as(Component.DeviceType, self.comp.device),
            self.pos,
            self.rotation,
            buffer[0..],
        );
    }

    pub fn intersects(self: *const GraphicComponent, positions: []const OccupiedGridPosition) bool {
        var buffer: [100]OccupiedGridPosition = undefined;

        const self_positons = self.getOccupiedGridPositions(buffer[0..]);
        return occupiedPointsIntersect(self_positons, positions);
    }

    pub fn getOccupiedGridPositions(
        self: *const GraphicComponent,
        position_buffer: []OccupiedGridPosition,
    ) []OccupiedGridPosition {
        return deviceOccupiedGridPositions(
            @as(Component.DeviceType, self.comp.device),
            self.pos,
            self.rotation,
            position_buffer[0..],
        );
    }

    pub fn renderPropertyBox(self: *GraphicComponent, selected_component_changed: bool) void {
        switch (@as(DeviceType, self.comp.device)) {
            inline else => |x| graphics_module(x).renderPropertyBox(
                &@field(self.comp.device, @tagName(x)),
                &self.value_buffer,
                selected_component_changed,
            ),
        }
    }

    pub fn isValueDisplayed(self: *const GraphicComponent) bool {
        switch (self.comp.device) {
            .resistor, .inductor, .capacitor => return true,
            else => return false,
        }
    }

    pub fn valueStr(self: *const GraphicComponent) []const u8 {
        return switch (self.comp.device) {
            .resistor => self.value_buffer.resistor.actual,
            .inductor => self.value_buffer.inductor.actual,
            .capacitor => self.value_buffer.capacitor.actual,
            else => @panic("the value for this type of component is not displayed"),
        };
    }

    pub fn defaultValueLabelPos(self: *const GraphicComponent) GridSubposition {
        const x: f32 = @floatFromInt(self.pos.x);
        const y: f32 = @floatFromInt(self.pos.y);
        return switch (self.rotation) {
            .right => .{
                .x = x + 1.5,
                .y = y - 0.8,
            },
            .left => .{
                .x = x - 1.5,
                .y = y - 0.8,
            },
            .top => .{
                .x = x + 0.5,
                .y = y - 1.7,
            },
            .bottom => .{
                .x = x + 0.5,
                .y = y + 1.3,
            },
        };
    }

    pub fn defaultNameLabelPos(self: *const GraphicComponent) GridSubposition {
        const x: f32 = @floatFromInt(self.pos.x);
        const y: f32 = @floatFromInt(self.pos.y);
        return switch (self.rotation) {
            .right => .{
                .x = x + 0.5,
                .y = y - 0.8,
            },
            .left => .{
                .x = x - 0.5,
                .y = y - 0.8,
            },
            .top => .{
                .x = x + 0.5,
                .y = y - 0.7,
            },
            .bottom => .{
                .x = x + 0.5,
                .y = y + 0.3,
            },
        };
    }

    pub fn setNewComponentName(self: *GraphicComponent) !void {
        self.comp.name = switch (@as(DeviceType, self.comp.device)) {
            inline else => |x| try graphics_module(x).setNewComponentName(
                self.name_buffer,
            ),
        };
    }

    pub fn hovered(
        self: *const GraphicComponent,
        grid_pos: GridSubposition,
        zoom: f32,
    ) bool {
        const shape = switch (@as(DeviceType, self.comp.device)) {
            inline else => |x| graphics_module(x).clickable_shape,
        };

        return shape.inside(self.pos, self.rotation, zoom, grid_pos);
    }

    pub fn render(
        self: *const GraphicComponent,
        vector_renderer: *const VectorRenderer,
        render_type: renderer.ElementRenderType,
        junctions: *const std.AutoHashMapUnmanaged(GridPosition, circuit.GraphicCircuit.Junction),
    ) !void {
        const dev_type = @as(DeviceType, self.comp.device);
        try renderComponent(
            dev_type,
            vector_renderer,
            self.pos,
            self.rotation,
            render_type,
            junctions,
        );
    }
};
