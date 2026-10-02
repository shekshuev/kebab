const std = @import("std");
const Io = std.Io;

const kebab = @import("kebab");

const config_mod = @import("config.zig");
const Config = config_mod.Config;

pub fn main(init: std.process.Init) !void {
    const cfg = try Config.load(init.minimal.args, init.environ_map);
    _ = cfg;
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}

test {
    _ = config_mod;
}
