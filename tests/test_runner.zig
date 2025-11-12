const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const test_count = builtin.test_functions.len;

    var passed_test_count: usize = 0;
    var total_elapsed: i64 = 0;

    // TODO: CLEANUP
    for (builtin.test_functions, 0..) |t, idx| {
        const real_test_name_idx = std.mem.lastIndexOfScalar(u8, t.name, '.').?;
        const real_test_name = t.name[real_test_name_idx + 1 ..];
        // -5 to remove ".test"
        const test_file_name = t.name[0 .. real_test_name_idx - 5];

        const start = std.time.microTimestamp();
        t.func() catch |err| {
            const elapsed = std.time.microTimestamp() - start;
            total_elapsed += elapsed;

            if (elapsed > 10_000) {
                const elapsed_in_ms = @divFloor(elapsed, 1_000);
                try stdout.print(
                    "\x1b[2m[ {}/{} ]\x1b[m \x1b[38;5;139m{s}/\x1b[31m{s}\x1b[m ... \x1b[31;1mfailed\x1b[m: {}\x1b[m ... \x1b[34m{}ms\x1b[m\n",
                    .{ idx + 1, test_count, test_file_name, real_test_name, err, elapsed_in_ms },
                );
            } else {
                try stdout.print(
                    "\x1b[2m[ {}/{} ]\x1b[m \x1b[38;5;139m{s}/\x1b[31m{s}\x1b[m ... \x1b[31;1mfailed\x1b[m: {}\x1b[m ... \x1b[34m{}\u{03BC}s\x1b[m\n",
                    .{ idx + 1, test_count, test_file_name, real_test_name, err, elapsed },
                );
            }
            try stdout.flush();

            continue;
        };
        const elapsed = std.time.microTimestamp() - start;
        total_elapsed += elapsed;
        if (elapsed > 10_000) {
            const elapsed_in_ms = @divFloor(elapsed, 1_000);
            try stdout.print(
                "\x1b[2m[ {}/{} ]\x1b[m \x1b[38;5;139m{s}/\x1b[32m{s}\x1b[m ... \x1b[32;1mok \x1b[m ... \x1b[34m{}ms\x1b[m\n",
                .{ idx + 1, test_count, test_file_name, real_test_name, elapsed_in_ms },
            );
        } else {
            try stdout.print(
                "\x1b[2m[ {}/{} ]\x1b[m \x1b[38;5;139m{s}/\x1b[32m{s}\x1b[m ... \x1b[32;1mok \x1b[m ... \x1b[34m{}\u{03BC}s\x1b[m\n",
                .{ idx + 1, test_count, test_file_name, real_test_name, elapsed },
            );
        }
        try stdout.flush();

        passed_test_count += 1;
    }

    try stdout.print("\n\x1b[2mTest report:\x1b[m\n", .{});
    try stdout.print(
        "\t\x1b[2mElapsed time:\x1b[m \x1b[34;1m{}ms\x1b[m\n",
        .{@divFloor(total_elapsed, 1000)},
    );
    try stdout.print(
        "\t\x1b[2mTests passed:\x1b[m \x1b[32;1m{}\x1b[m \x1b[2mout of\x1b[m \x1b[34;1m{}\x1b[m\n",
        .{ passed_test_count, test_count },
    );
    try stdout.print(
        "\t\x1b[2mTests failed:\x1b[m \x1b[31;1m{}\x1b[m \x1b[2mout of\x1b[m \x1b[34;1m{}\x1b[m\n",
        .{ test_count - passed_test_count, test_count },
    );

    try stdout.flush();
}

pub const std_options: std.Options = .{
    .logFn = testLog,
};

pub fn testLog(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = message_level;
    _ = scope;
    _ = format;
    _ = args;
}
