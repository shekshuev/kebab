const std = @import("std");

const webui_build = @import("zig_webui");

pub fn build(b: *std.Build) !void {
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

    const tui_mod = b.createModule(.{
        .root_source_file = b.path("src/tui/app.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = core_mod },
        },
    });

    const zig_webui = b.dependency("zig_webui", .{
        .target = target,
        .optimize = optimize,
        .enable_tls = false,
        .is_static = true,
    });

    const gui_mod = b.createModule(.{
        .root_source_file = b.path("src/gui/app.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = core_mod },
            .{ .name = "webui", .module = zig_webui.module("webui") },
        },
    });

    const exe = b.addExecutable(.{
        .name = "kebab",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = core_mod },
                .{ .name = "tui", .module = tui_mod },
                .{ .name = "gui", .module = gui_mod },
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
                    .name = "tui",
                    .module = tui_mod,
                },
                .{
                    .name = "gui",
                    .module = gui_mod,
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

    const tui_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tui/app.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = core_mod },
            },
        }),
    });

    const gui_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gui/app.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = core_mod },
            },
        }),
    });

    const run_app_tests = b.addRunArtifact(app_tests);
    const run_core_tests = b.addRunArtifact(core_tests);
    const run_tui_tests = b.addRunArtifact(tui_tests);
    const run_gui_tests = b.addRunArtifact(gui_tests);
    test_step.dependOn(&run_app_tests.step);
    test_step.dependOn(&run_core_tests.step);
    test_step.dependOn(&run_tui_tests.step);
    test_step.dependOn(&run_gui_tests.step);

    try webui_build.addEmbeddedDir(b, gui_mod, .{
        .path = "assets",
        .import_name = "embedded_assets",
        .http_responses = false,
    });
}
