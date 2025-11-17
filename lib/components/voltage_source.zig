const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");
const MNA = @import("../MNA.zig");

const Component = component.Component;
const Float = bland.Float;
const StampOptions = Component.Device.StampOptions;

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .voltage_source = 5 };
}

pub fn formatValue(value: Float, buf: []u8) !?[]const u8 {
    return try bland.units.formatUnitBuf(buf, .voltage, value, 3);
}

pub fn stampMatrix(
    v: Float,
    terminal_node_ids: []const usize,
    mna: *MNA,
    current_group_2_idx: ?usize,
    stamp_opts: StampOptions,
) void {
    const v_plus = terminal_node_ids[0];
    const v_minus = terminal_node_ids[1];
    const curr_idx = current_group_2_idx orelse @panic("Invalid voltage stamp");

    // TODO: explain stamping
    switch (stamp_opts) {
        .dc, .sin_steady_state => {
            mna.stampVoltageCurrent(v_plus, curr_idx, 1);
            mna.stampVoltageCurrent(v_minus, curr_idx, -1);

            mna.stampCurrentVoltage(curr_idx, v_plus, 1);
            mna.stampCurrentVoltage(curr_idx, v_minus, -1);
            mna.stampCurrentRHS(curr_idx, v);
        },
        .transient => |trans| {
            const freq = 50;
            const voltage = v * @sin(2 * std.math.pi * freq * trans.time);

            mna.stampVoltageCurrent(v_plus, curr_idx, 1);
            mna.stampVoltageCurrent(v_minus, curr_idx, -1);

            mna.stampCurrentVoltage(curr_idx, v_plus, 1);
            mna.stampCurrentVoltage(curr_idx, v_minus, -1);
            mna.stampCurrentRHS(curr_idx, voltage);
        },
    }
}
