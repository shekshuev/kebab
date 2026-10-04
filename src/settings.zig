const std = @import("std");

pub const SettingsConnectOption = struct {
    name: []const u8,
    host: []const u8,
    port: u16,
    user: []const u8,
    pass: []const u8,
    database: []const u8,
};

pub const Settings = struct {
    connect_options: []SettingsConnectOption,
};

pub const SettingsManager = struct {
    arena: std.heap.ArenaAllocator,
    io: std.Io,
    settings: Settings,
    path: []const u8,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, config_dir: []const u8) !SettingsManager {
        return SettingsManager{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .io = io,
            .settings = Settings{
                .connect_options = &[_]SettingsConnectOption{},
            },
            .path = try std.fs.path.join(
                allocator,
                &[_][]const u8{ config_dir, "settings.json" },
            ),
        };
    }

    pub fn deinit(self: *SettingsManager) void {
        self.arena.child_allocator.free(self.path);
        self.arena.deinit();
    }

    pub fn load(self: *SettingsManager) !void {
        var file = std.Io.Dir.cwd().openFile(
            self.io,
            self.path,
            .{ .mode = .read_only },
        ) catch |err| {
            if (err == error.FileNotFound) return;
            return err;
        };
        defer file.close(self.io);

        const file_size = try file.length(self.io);
        if (file_size == 0) return;

        const content = try self.arena.child_allocator.alloc(u8, @intCast(file_size));
        defer self.arena.child_allocator.free(content);

        _ = self.arena.reset(.retain_capacity);

        const bytes_read = try file.readPositionalAll(self.io, content, 0);

        self.settings = try std.json.parseFromSliceLeaky(
            Settings,
            self.arena.allocator(),
            content[0..bytes_read],
            .{
                .allocate = .alloc_always,
                .ignore_unknown_fields = true,
            },
        );
    }

    pub fn save(self: *SettingsManager, settings: Settings) !void {
        if (std.fs.path.dirname(self.path)) |dir_path| {
            _ = try std.Io.Dir.cwd().createDirPathStatus(
                self.io,
                dir_path,
                .default_dir,
            );
        }

        var file = try std.Io.Dir.cwd().createFile(
            self.io,
            self.path,
            .{},
        );
        defer file.close(self.io);

        try file.lock(self.io, .exclusive);
        defer file.unlock(self.io);

        var buf: [4096]u8 = undefined;
        var fw = file.writerStreaming(self.io, &buf);

        try std.json.fmt(settings, .{ .whitespace = .indent_2 }).format(&fw.interface);
        try fw.flush();
        try file.sync(self.io);
    }
};

test "should init and deinit without leaks" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_len = try tmp.dir.realPath(std.testing.io, &dir_buf);
    const test_dir = dir_buf[0..dir_len];

    var mgr = try SettingsManager.init(
        std.testing.allocator,
        std.testing.io,
        test_dir,
    );
    defer mgr.deinit();

    try std.testing.expect(mgr.path.len > 0);
    try std.testing.expectEqual(@as(usize, 0), mgr.settings.connect_options.len);
}

test "should load handles missing file gracefully" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_len = try tmp.dir.realPath(std.testing.io, &dir_buf);
    const test_dir = dir_buf[0..dir_len];

    var mgr = try SettingsManager.init(std.testing.allocator, std.testing.io, test_dir);
    defer mgr.deinit();

    try mgr.load();
    try std.testing.expectEqual(@as(usize, 0), mgr.settings.connect_options.len);
}

test "should save and load round-trip" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_len = try tmp.dir.realPath(std.testing.io, &dir_buf);
    const test_dir = dir_buf[0..dir_len];

    var mgr = try SettingsManager.init(
        std.testing.allocator,
        std.testing.io,
        test_dir,
    );
    defer mgr.deinit();

    const sample_options = [_]SettingsConnectOption{
        .{
            .name = "Local Postgres",
            .host = "127.0.0.1",
            .port = 5432,
            .user = "postgres",
            .pass = "secret123",
            .database = "postgres",
        },
        .{
            .name = "Prod Replica",
            .host = "db.internal",
            .port = 6432,
            .user = "readonly",
            .pass = "nopass",
            .database = "analytics",
        },
    };

    try mgr.save(.{ .connect_options = @constCast(&sample_options) });
    try mgr.load();

    try std.testing.expectEqual(@as(usize, 2), mgr.settings.connect_options.len);

    const c1 = mgr.settings.connect_options[0];
    try std.testing.expectEqualStrings("Local Postgres", c1.name);
    try std.testing.expectEqualStrings("127.0.0.1", c1.host);
    try std.testing.expectEqual(@as(u16, 5432), c1.port);
    try std.testing.expectEqualStrings("postgres", c1.user);
    try std.testing.expectEqualStrings("secret123", c1.pass);
    try std.testing.expectEqualStrings("postgres", c1.database);

    const c2 = mgr.settings.connect_options[1];
    try std.testing.expectEqualStrings("Prod Replica", c2.name);
    try std.testing.expectEqualStrings("db.internal", c2.host);
    try std.testing.expectEqual(@as(u16, 6432), c2.port);
    try std.testing.expectEqualStrings("readonly", c2.user);
    try std.testing.expectEqualStrings("nopass", c2.pass);
    try std.testing.expectEqualStrings("analytics", c2.database);
}

test "should truncate older larger file properly on save" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_len = try tmp.dir.realPath(std.testing.io, &dir_buf);
    const test_dir = dir_buf[0..dir_len];

    var mgr = try SettingsManager.init(std.testing.allocator, std.testing.io, test_dir);
    defer mgr.deinit();

    const initial_options = [_]SettingsConnectOption{
        .{
            .name = "Long Connection Name One",
            .host = "extremely-long-hostname-for-testing-purposes.local",
            .port = 5432,
            .user = "long_username_here",
            .pass = "super_long_password_string_12345",
            .database = "production_database_main",
        },
        .{
            .name = "Long Connection Name Two",
            .host = "another-very-long-hostname-for-testing.internal",
            .port = 5433,
            .user = "second_user",
            .pass = "another_long_pass",
            .database = "secondary_db",
        },
    };
    try mgr.save(.{ .connect_options = @constCast(&initial_options) });

    const small_options = [_]SettingsConnectOption{
        .{
            .name = "Dev",
            .host = "localhost",
            .port = 5432,
            .user = "pg",
            .pass = "pg",
            .database = "db",
        },
    };
    try mgr.save(.{ .connect_options = @constCast(&small_options) });

    try mgr.load();
    try std.testing.expectEqual(@as(usize, 1), mgr.settings.connect_options.len);
    try std.testing.expectEqualStrings("Dev", mgr.settings.connect_options[0].name);
}

test "should not leak or corrupt memory on multiple loads" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_len = try tmp.dir.realPath(std.testing.io, &dir_buf);
    const test_dir = dir_buf[0..dir_len];

    var mgr = try SettingsManager.init(std.testing.allocator, std.testing.io, test_dir);
    defer mgr.deinit();

    const sample = [_]SettingsConnectOption{
        .{
            .name = "Main",
            .host = "localhost",
            .port = 5432,
            .user = "postgres",
            .pass = "postgres",
            .database = "postgres",
        },
    };
    try mgr.save(.{ .connect_options = @constCast(&sample) });

    for (0..5) |_| {
        try mgr.load();
        try std.testing.expectEqual(@as(usize, 1), mgr.settings.connect_options.len);
        try std.testing.expectEqualStrings("Main", mgr.settings.connect_options[0].name);
    }
}

test "should ignore unknown fields on load" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_len = try tmp.dir.realPath(std.testing.io, &dir_buf);
    const test_dir = dir_buf[0..dir_len];

    var mgr = try SettingsManager.init(std.testing.allocator, std.testing.io, test_dir);
    defer mgr.deinit();

    if (std.fs.path.dirname(mgr.path)) |dir_path| {
        _ = try std.Io.Dir.cwd().createDirPathStatus(std.testing.io, dir_path, .default_dir);
    }

    const raw_json =
        \\{
        \\  "unknown_root_version": 42,
        \\  "connect_options": [
        \\    {
        \\      "name": "Legacy Conn",
        \\      "host": "10.0.0.1",
        \\      "port": 5432,
        \\      "user": "admin",
        \\      "pass": "secret",
        \\      "database": "app_db",
        \\      "future_ssl_mode": "require",
        \\      "timeout_ms": 5000
        \\    }
        \\  ]
        \\}
    ;

    var file = try std.Io.Dir.cwd().createFile(std.testing.io, mgr.path, .{});
    defer file.close(std.testing.io);
    try file.writeStreamingAll(std.testing.io, raw_json);

    try mgr.load();

    try std.testing.expectEqual(@as(usize, 1), mgr.settings.connect_options.len);
    try std.testing.expectEqualStrings("Legacy Conn", mgr.settings.connect_options[0].name);
    try std.testing.expectEqualStrings("app_db", mgr.settings.connect_options[0].database);
}
