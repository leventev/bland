const std = @import("std");
const bland = @import("bland.zig");

pub const Unit = enum {
    dimensionless,
    voltage,
    current,
    power,
    resistance,
    capacitance,
    inductance,
    frequency,

    fn symbol(self: Unit) []const u8 {
        return switch (self) {
            .dimensionless => "",
            .voltage => "V",
            .current => "A",
            .power => "W",
            .resistance => "\u{03A9}", // big omega
            .capacitance => "F",
            .inductance => "H",
            .frequency => "Hz",
        };
    }
};

const Prefix = struct {
    symbol: []const u8,
    threshold: bland.Float,
};

// must be in descending order
const si_prefixes = [_]Prefix{
    .{ .symbol = "P", .threshold = 1e15 },
    .{ .symbol = "T", .threshold = 1e12 },
    .{ .symbol = "G", .threshold = 1e9 },
    .{ .symbol = "M", .threshold = 1e6 },
    .{ .symbol = "k", .threshold = 1e3 },
    .{ .symbol = "", .threshold = 1 },
    .{ .symbol = "m", .threshold = 1e-3 },
    .{ .symbol = "\u{03BC}", .threshold = 1e-6 }, // mu
    .{ .symbol = "n", .threshold = 1e-9 },
    .{ .symbol = "p", .threshold = 1e-12 },
    .{ .symbol = "f", .threshold = 1e-15 },
};

pub fn formatUnitBuf(
    buff: []u8,
    unit: Unit,
    val: bland.Float,
    precision: usize,
) std.fmt.BufPrintError![]u8 {
    const unit_symbol = unit.symbol();

    if (val == 0)
        return std.fmt.bufPrint(buff, "0{s}", .{unit_symbol});

    if (unit == .dimensionless)
        return std.fmt.bufPrint(buff, "{d:.[1]}", .{ val, precision });

    inline for (si_prefixes) |prefix| {
        if (@abs(val) >= prefix.threshold) {
            return std.fmt.bufPrint(buff, "{d:.[3]}{s}{s}", .{
                val / prefix.threshold,
                prefix.symbol,
                unit_symbol,
                precision,
            });
        }
    }

    // if the value is lower than the last threshold then print it in scientific notation
    return std.fmt.bufPrint(buff, "{e:.[2]}{s}", .{
        val,
        unit_symbol,
        precision,
    });
}

pub fn formatUnitAlloc(
    gpa: std.mem.Allocator,
    unit: Unit,
    val: bland.Float,
    precision: usize,
) std.mem.Allocator.Error![]u8 {
    const unit_symbol = unit.symbol();

    if (val == 0)
        return std.fmt.allocPrint(gpa, "0{s}", .{unit_symbol});

    if (unit == .dimensionless)
        return std.fmt.allocPrint(gpa, "{d:.[1]}", .{ val, precision });

    inline for (si_prefixes) |prefix| {
        if (@abs(val) >= prefix.threshold) {
            return std.fmt.allocPrint(gpa, "{d:.[3]}{s}{s}", .{
                val / prefix.threshold,
                prefix.symbol,
                unit_symbol,
                precision,
            });
        }
    }

    // if the value is lower than the last threshold then print it in scientific notation
    return std.fmt.allocPrint(gpa, "{e:.[2]}{s}", .{
        val,
        unit_symbol,
        precision,
    });
}
