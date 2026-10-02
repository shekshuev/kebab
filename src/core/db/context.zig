const std = @import("std");

pub const SessionContext = struct {
    timezone_name: [64]u8,
    timezone_offset_min: i16,
    server_version: [64]u8,

    pub fn getTimezone(self: *const SessionContext) []const u8 {
        return std.mem.sliceTo(&self.timezone_name, 0);
    }

    pub fn getServerVersion(self: *const SessionContext) []const u8 {
        return std.mem.sliceTo(&self.server_version, 0);
    }
};
