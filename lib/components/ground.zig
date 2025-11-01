const std = @import("std");
const bland = @import("../bland.zig");
const component = @import("../component.zig");

const Component = component.Component;

pub fn defaultValue(_: std.mem.Allocator) !Component.Device {
    return Component.Device{ .ground = {} };
}

pub fn formatValue(value: u32, buf: []u8) !?[]const u8 {
    _ = value;
    _ = buf;
    return null;
}
