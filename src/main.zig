const std = @import("std");

const kebab = @import("kebab");

const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    _ = init;
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
