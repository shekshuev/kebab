const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pg_module = b.dependency("pg", .{}).module("pg");

    const core_mod = b.createModule(.{
        .root_source_file = b.path("src/core/core.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "pg", .module = pg_module },
        },
    });

    const dvui_module = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .sdl3,
    });

    const exe = b.addExecutable(.{
        .name = "zpg",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = core_mod },
                .{ .name = "dvui", .module = dvui_module.module("dvui_sdl3") },
            },
        }),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run tests");

    const app_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "core",
                    .module = core_mod,
                },
                .{
                    .name = "dvui",
                    .module = dvui_module.module("dvui_sdl3"),
                },
            },
        }),
    });

    const core_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/core/core.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{
                .name = "pg",
                .module = pg_module,
            }},
        }),
    });

    const run_app_tests = b.addRunArtifact(app_tests);
    const run_core_tests = b.addRunArtifact(core_tests);
    test_step.dependOn(&run_app_tests.step);
    test_step.dependOn(&run_core_tests.step);
}
