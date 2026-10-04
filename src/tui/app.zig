const std = @import("std");

const core = @import("core");

const Client = core.client.Client;
const ConnectOptions = core.options.ConnectOptions;

pub fn run(init: std.process.Init, opts: ConnectOptions) !void {
    var client = try Client.init(init.io, init.gpa, opts);
    defer client.deinit();

    if (try client.checkConnection()) {
        std.debug.print("Connected successfully.\n", .{});
    }

    try client.syncSessionContext();
    std.debug.print("Session synced.\n", .{});
}
