const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("lib/bland.zig"),
        .target = target,
        .optimize = optimize,
    });

    const bland_lib = b.addLibrary(.{
        .name = "bland",
        .linkage = .static,
        .root_module = lib_mod,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "bland",
        .root_module = exe_mod,
    });

    exe.linkLibrary(bland_lib);
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const dvui = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .sdl3,
    });

    exe.root_module.addImport("dvui", dvui.module("dvui_sdl3"));
    exe.root_module.addImport("bland", lib_mod);

    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/main.zig"),
            .target = target,
            .imports = &.{
                .{ .name = "bland", .module = lib_mod },
            },
        }),
        .test_runner = .{
            .path = b.path("tests/test_runner.zig"),
            .mode = .simple,
        },
    });

    const test_step = b.step("test", "Run unit tests");
    const run_unit_tests = b.addRunArtifact(lib_unit_tests);
    run_unit_tests.skip_foreign_checks = true;
    test_step.dependOn(&run_unit_tests.step);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
