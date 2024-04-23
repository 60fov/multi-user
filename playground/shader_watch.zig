const std = @import("std");

const mu = @import("multi-user");
const asset = mu.asset;

pub fn main() !void {
    // var scratch_buffer: [4096]u8 = undefined;
    // const cwd_path = try std.fs.cwd().realpath(".", &scratch_buffer);
    // std.debug.print("cwd: {s}\n", .{cwd_path});
    var src = asset.AssetFile.init("playground/shaders/test");
    defer src.deinit();

    var buffer: [4096]u8 = undefined;

    while (true) {
        std.time.sleep(10);
        if (src.watch()) {
            std.debug.print("file has changed\n", .{});
            const buf = src.read(buffer[0..]);
            std.debug.print("new contents\n {s}\n", .{buf});
        }
    }
}
