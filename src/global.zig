const std = @import("std");
const builtin = @import("builtin");

const shader = @import("graphics/shader.zig");

const dir_buffer_size = 1 * 1024 * 1024;
var dir_buffer: []u8 = undefined;
var dir_fba: std.heap.FixedBufferAllocator = undefined;
pub var dir_allocator: std.mem.Allocator = undefined;

pub const scratch_buffer_size = 5 * 1024 * 1024;
pub var scratch_buffer: []u8 = undefined;

pub const dynamic_buffer_size = 5 * 1024 * 1024;
pub var dynamic_buffer: []u8 = undefined;
pub var dynamic_buffer_fba: std.heap.FixedBufferAllocator = undefined;
var dynamic_allocator: std.mem.Allocator = undefined;

var base_dir: std.fs.Dir = undefined;
var asset_dir: std.fs.Dir = undefined;

pub fn init(allctr: std.mem.Allocator) !void {
    dir_buffer = try allctr.alloc(u8, dir_buffer_size);
    dir_fba = std.heap.FixedBufferAllocator.init(dir_buffer);
    dir_allocator = dir_fba.allocator();

    scratch_buffer = try allctr.alloc(u8, scratch_buffer_size);

    dynamic_buffer = try allctr.alloc(u8, dynamic_buffer_size);
    dynamic_buffer_fba = std.heap.FixedBufferAllocator.init(dynamic_buffer);
    dynamic_allocator = dynamic_buffer_fba.allocator();

    if (builtin.mode != .Debug) {
        const path = try std.fs.selfExeDirPath(scratch_buffer);
        base_dir = try std.fs.openDirAbsolute(path, .{});
    } else {
        base_dir = std.fs.cwd();
    }

    const p = try base_dir.realpath(".", scratch_buffer);
    std.debug.print("base directory: {s}\n", .{p});

    asset_dir = try base_dir.openDir("assets", .{});
}

pub fn deinit(allctr: std.mem.Allocator) void {
    dynamic_buffer_fba = undefined;
    allctr.free(dir_buffer);
    allctr.free(scratch_buffer);
}

pub fn baseDir() std.fs.Dir {
    return base_dir;
}

pub fn assetDir() std.fs.Dir {
    return asset_dir;
}

pub fn allocator() std.mem.Allocator {
    return dynamic_allocator;
}
