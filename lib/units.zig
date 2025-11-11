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

    pub fn symbol(self: Unit) []const u8 {
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
    ascii_symbol: []const u8,
    decimal: bland.Float,
};

// must be in descending order
const si_prefixes = [_]Prefix{
    .{ .symbol = "P", .ascii_symbol = "P", .decimal = 1e15 },
    .{ .symbol = "T", .ascii_symbol = "T", .decimal = 1e12 },
    .{ .symbol = "G", .ascii_symbol = "G", .decimal = 1e9 },
    .{ .symbol = "M", .ascii_symbol = "M", .decimal = 1e6 },
    .{ .symbol = "k", .ascii_symbol = "k", .decimal = 1e3 },
    .{ .symbol = "", .ascii_symbol = "", .decimal = 1 },
    .{ .symbol = "m", .ascii_symbol = "m", .decimal = 1e-3 },
    .{ .symbol = "\u{03BC}", .ascii_symbol = "u", .decimal = 1e-6 }, // mu
    .{ .symbol = "n", .ascii_symbol = "n", .decimal = 1e-9 },
    .{ .symbol = "p", .ascii_symbol = "p", .decimal = 1e-12 },
    .{ .symbol = "f", .ascii_symbol = "f", .decimal = 1e-15 },
};

fn getPrefixDecimal(pref_str: []const u8) ?bland.Float {
    for (si_prefixes) |prefix| {
        if (std.mem.eql(u8, prefix.ascii_symbol, pref_str)) {
            return prefix.decimal;
        }
    }

    return null;
}

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
        if (@abs(val) >= prefix.decimal) {
            return std.fmt.bufPrint(buff, "{d:.[3]}{s}{s}", .{
                val / prefix.decimal,
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
        if (@abs(val) >= prefix.decimal) {
            return std.fmt.allocPrint(gpa, "{d:.[3]}{s}{s}", .{
                val / prefix.decimal,
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

pub fn formatPrefixBuf(
    buff: []u8,
    val: bland.Float,
    precision: usize,
) std.fmt.BufPrintError![]u8 {
    if (val == 0)
        return std.fmt.bufPrint(buff, "0", .{});

    inline for (si_prefixes) |prefix| {
        if (@abs(val) >= prefix.decimal) {
            return std.fmt.bufPrint(buff, "{d:.[2]}{s}", .{
                val / prefix.decimal,
                prefix.symbol,
                precision,
            });
        }
    }

    // if the value is lower than the last threshold then print it in scientific notation
    return std.fmt.bufPrint(buff, "{e:.[1]}", .{
        val,
        precision,
    });
}

pub fn formatPrefixAlloc(
    gpa: std.mem.Allocator,
    val: bland.Float,
    precision: usize,
) std.mem.Allocator.Error![]u8 {
    if (val == 0)
        return std.fmt.allocPrint(gpa, "0", .{});

    inline for (si_prefixes) |prefix| {
        if (@abs(val) >= prefix.decimal) {
            return std.fmt.allocPrint(gpa, "{d:.[2]}{s}", .{
                val / prefix.decimal,
                prefix.symbol,
                precision,
            });
        }
    }

    // if the value is lower than the last threshold then print it in scientific notation
    return std.fmt.allocPrint(gpa, "{e:.[1]}", .{
        val,
        precision,
    });
}

pub const UnitError = error{ InvalidNumber, InvalidPrefix };

fn isNumber(c: u8) bool {
    return c >= '0' and c <= '9';
}

pub fn parseWithoutUnitSymbol(str: []const u8) UnitError!bland.Float {
    if (str.len == 0) return UnitError.InvalidNumber;

    var idx = str.len - 1;
    while (idx > 0 and !isNumber(str[idx])) : (idx -= 1) {}

    // only possible is if we reached the first character
    if (!isNumber(str[idx])) return UnitError.InvalidNumber;

    // no prefix
    if (idx == str.len - 1) {
        const val = std.fmt.parseFloat(bland.Float, str) catch return UnitError.InvalidNumber;
        return val;
    } else {
        const prefix_start_idx = idx + 1;

        const prefix_len = str.len - prefix_start_idx;
        const number_len = str.len - prefix_len;

        const number = str[0..number_len];
        const prefix = str[prefix_start_idx..str.len];

        const val = std.fmt.parseFloat(bland.Float, number) catch return UnitError.InvalidNumber;
        const prefix_decimal = getPrefixDecimal(prefix) orelse return UnitError.InvalidPrefix;
        return val * prefix_decimal;
    }
}
