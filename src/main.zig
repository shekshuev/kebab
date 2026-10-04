const builtin = @import("builtin");
const std = @import("std");

const core = @import("core");
const gui = @import("gui");
const kebab = @import("kebab");
const tui = @import("tui");

const config_mod = @import("config.zig");
const settings_mod = @import("settings.zig");

const Io = std.Io;
const Config = config_mod.Config;
const SettingsManager = settings_mod.SettingsManager;

pub const AppError = error{ AppDataDirUnavailable, UnsupportedOS };

pub fn main(init: std.process.Init) !u8 {
    const env = init.environ_map;
    const cfg = try Config.load(init.minimal.args, env);
    const base_dir = switch (builtin.os.tag) {
        .macos => env.get("HOME") orelse return AppError.AppDataDirUnavailable,
        .linux => env.get("XDG_DATA_HOME") orelse env.get("HOME") orelse return AppError.AppDataDirUnavailable,
        .windows => env.get("LOCALAPPDATA") orelse return AppError.AppDataDirUnavailable,
        else => return AppError.UnsupportedOS,
    };

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const app_dir = try switch (builtin.os.tag) {
        .macos => std.fmt.bufPrint(&path_buf, "{s}/Library/Application Support/zpg", .{base_dir}),
        .linux => std.fmt.bufPrint(&path_buf, "{s}/.local/share/zpg", .{base_dir}),
        .windows => std.fmt.bufPrint(&path_buf, "{s}\\zpg", .{base_dir}),
        else => return AppError.UnsupportedOS,
    };

    var settings_manager = try SettingsManager.init(init.gpa, init.io, app_dir);
    defer settings_manager.deinit();

    const opts = core.options.ConnectOptions{
        .database = cfg.db_name,
        .host = cfg.db_host,
        .port = cfg.db_port,
        .user = cfg.db_user,
        .pass = cfg.db_pass,
    };

    switch (cfg.mode) {
        .gui => {
            std.log.info("Starting GUI mode...", .{});
            try gui.run(init, opts);
            return 0;
        },
        .tui => {
            std.log.info("Starting TUI mode...", .{});
            try tui.run(init, opts);
            return 0;
        },
    }
}

test {
    _ = config_mod;
    _ = settings_mod;
}
