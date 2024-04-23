const std = @import("std");

const global = @import("global.zig");
const shader = @import("graphics/shader.zig");

pub const AssetFile = struct {
    path: []const u8,
    file: std.fs.File,
    last_modified: i128,

    pub fn init(path: []const u8) AssetFile {
        const owned_path = global.dir_allocator.dupe(u8, path) catch unreachable;

        const file = global.assetDir().openFile(path, .{ .mode = .read_only }) catch {
            std.debug.print("failed to open asset file: {s}\n", .{path});
            unreachable;
        };

        const meta = file.metadata() catch {
            std.debug.print("failed to read metadata, file: {s}\n", .{path});
            file.close();
            unreachable;
        };

        return AssetFile{
            .path = owned_path,
            .file = file,
            .last_modified = meta.modified(),
        };
    }

    pub fn deinit(self: *AssetFile) void {
        self.file.close();
        global.dir_allocator.free(self.path);
        self.* = undefined;
    }

    pub fn hasChanged(self: AssetFile) !bool {
        const meta = try self.file.metadata();
        return meta.modified() != self.last_modified;
    }

    pub fn update(self: *AssetFile) !void {
        const meta = try self.file.metadata();
        self.last_modified = meta.modified();
    }

    /// an immediate-mode watch function.
    pub fn watch(self: *AssetFile) bool {
        const changed = self.hasChanged() catch {
            std.debug.print("failed to read metadata, file: {s}\n", .{self.path});
            return false;
        };
        if (changed) self.update() catch {
            std.debug.print("failed to read metadata, file: {s}\n", .{self.path});
            return false;
        };
        return changed;
    }

    /// returned buffer will be invalid once called again.
    pub fn read(self: AssetFile, buffer: []u8) []const u8 {
        self.file.seekTo(0) catch {
            std.debug.print("failed to seek to beginning of file: {s}\n", .{self.path});
            unreachable;
        };
        std.debug.print("reading file: {s}\n", .{self.path});
        const size = self.file.reader().readAll(buffer) catch {
            std.debug.print("failed to read file: {s}\n", .{self.path});
            unreachable;
        };
        std.debug.print("read {d} bytes into scratch buffer\n", .{size});
        return buffer[0..size];
    }
};

// TODO
// many asset file to asset reload func relationship
// manage loading/unloading files at correct times eg before opengl, after opengl, per client, etc (probably using fn pointers)

pub fn Manager(T: type) type {
    return struct {
        const Self = @This();
        const AssetManageFn = *const fn (self: *T) void;

        table: std.StringHashMap(T),
        asset_manage_fn: AssetManageFn,

        pub fn init(allocator: std.mem.Allocator, asset_manage_fn: AssetManageFn) Self {
            return Self{
                .table = std.StringHashMap(T).init(allocator),
                .asset_manage_fn = asset_manage_fn,
            };
        }

        pub fn deinit(self: *Self) void {
            self.table.deinit();
            self.* = undefined;
        }

        pub fn add(self: *Self, name: []const u8, value: T) void {
            self.table.put(name, value) catch {
                std.debug.print("failed to add to shader manager, value: {s}\n", .{name});
                unreachable;
            };
        }

        pub fn get(self: Self, name: []const u8) T {
            if (self.table.get(name)) |asset| {
                return asset;
            } else {
                std.debug.print("no asset loaded named: {s}\n", .{name});
                unreachable;
            }
        }

        pub fn manage(self: *Self) void {
            var iter = self.table.valueIterator();
            while (iter.next()) |*asset| {
                self.asset_manage_fn(asset);
            }
        }
    };
}
