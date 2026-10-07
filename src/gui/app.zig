const std = @import("std");

const core = @import("core");
const webui = @import("webui");

const ConnectOptions = core.options.ConnectOptions;

pub fn run(init: std.process.Init, opts: ConnectOptions) !void {
    _ = init;
    _ = opts;
    var win = webui.newWindow();
    try win.setRootFolder("assets");
    try win.show("index.html");
    webui.wait();
    webui.clean();
    std.debug.print("Not implemented.\n", .{});
}
