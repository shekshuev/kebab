const std = @import("std");

const core = @import("core");

const ConnectOptions = core.options.ConnectOptions;

pub fn run(init: std.process.Init, opts: ConnectOptions) !void {
    _ = init;
    _ = opts;
    std.debug.print("Not implemented.\n", .{});
}
