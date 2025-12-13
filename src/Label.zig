const std = @import("std");
const circuit = @import("circuit.zig");
const bland = @import("bland");
const VectorRenderer = @import("VectorRenderer.zig");
const dvui = @import("dvui");
const global = @import("global.zig");

const Component = bland.Component;
const GridSubposition = circuit.GridSubposition;

const Label = @This();

pos: GridSubposition,
text_backing: TextBacking,

pub const TextBacking = union(enum) {
    component_name: Component.Id,

    pub fn retrieve(self: TextBacking) []const u8 {
        switch (self) {
            .component_name => |id| {
                const id_int = @intFromEnum(id);
                return circuit.main_circuit.graphic_components.items[id_int].comp.name;
            },
        }
    }
};

pub fn renderLabel(
    vector_renderer: *const VectorRenderer,
    pos: GridSubposition,
    text_backing: TextBacking,
    fg_color: dvui.Color,
    bg_color: ?dvui.Color,
) void {
    const text = text_backing.retrieve();
    vector_renderer.renderText(
        .{
            .x = pos.x,
            .y = pos.y,
        },
        text,
        fg_color,
        bg_color,
    ) catch {};
}

pub fn owner(self: Label) ?Component.Id {
    return switch (self.text_backing) {
        .component_name => |id| id,
    };
}

pub fn render(
    self: Label,
    vector_renderer: *const VectorRenderer,
    is_hovered: bool,
) void {
    const bg_color = if (is_hovered) dvui.themeGet().highlight.fill else null;
    renderLabel(
        vector_renderer,
        self.pos,
        self.text_backing,
        dvui.Color.white,
        bg_color,
    );
}

pub fn hovered(self: Label, mouse_pos: GridSubposition, zoom: f32) bool {
    const f = dvui.Font{
        .id = .fromName(global.font_name),
        .size = global.circuit_font_size * zoom,
        .line_height_factor = 1,
    };

    const text = self.text_backing.retrieve();
    const label_size = dvui.Font.textSize(f, text);
    const grid_size = VectorRenderer.grid_cell_px_size * zoom;

    const rect_width = label_size.w / grid_size;
    const rect_height = label_size.h / grid_size;

    const x1 = self.pos.x;
    const y1 = self.pos.y;
    const x2 = self.pos.x + rect_width;
    const y2 = self.pos.y + rect_height;

    return mouse_pos.x >= x1 and mouse_pos.y >= y1 and mouse_pos.x <= x2 and mouse_pos.y <= y2;
}
