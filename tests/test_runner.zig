const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const test_count = builtin.test_functions.len;

    var passed_test_count: usize = 0;

    const start = std.time.milliTimestamp();
    for (builtin.test_functions, 0..) |t, idx| {
        t.func() catch |err| {
            try stdout.print(
                "\x1b[2m[ {}/{} ]\x1b[m \x1b[31m{s}\x1b[m ... \x1b[31;1mfailed\x1b[m: {}\n",
                .{ idx + 1, test_count, t.name, err },
            );
            continue;
        };
        try stdout.print(
            "\x1b[2m[ {}/{} ]\x1b[m \x1b[32m{s}\x1b[m ... \x1b[32;1mok\x1b[m\n",
            .{ idx + 1, test_count, t.name },
        );
        passed_test_count += 1;
    }
    const elapsed = std.time.milliTimestamp() - start;

    try stdout.print("\n\x1b[2mTest report:\x1b[m\n", .{});
    try stdout.print(
        "\t\x1b[2mElapsed time:\x1b[m \x1b[34;1m{}ms\x1b[m\n",
        .{elapsed},
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
