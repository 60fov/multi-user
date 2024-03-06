const std = @import("std");
const assert = std.debug.assert;

/// yoink'd from https://github.com/andrewrk/tetris/blob/master/src/Bmp.zig, ty andrew
/// augemented w/ https://stackoverflow.com/questions/17967480/parse-read-bitmap-file-in-c, ty Conor Taylor
pub const Bmp = struct {
    width: u32,
    height: u32,
    raw: []const u8,

    const Header = extern struct {
        magic: [2]u8,
        size: u32 align(1),
        reserved: u32 align(1),
        pixel_offset: u32 align(1),
    };

    const Info = extern struct {
        biSize: u32 align(1),
        width: i32 align(1),
        height: i32 align(1),
        planes: u16 align(1),
        bitPix: u16 align(1),
        biCompression: u32 align(1),
        biSizeImage: u32 align(1),
        biXPelsPerMeter: i32 align(1),
        biYPelsPerMeter: i32 align(1),
        biClrUsed: u32 align(1),
        biClrImportant: u32 align(1),
    };

    pub fn create(compressed_bytes: []const u8) Bmp {
        const header: *const Header = @ptrCast(compressed_bytes);
        assert(header.magic[0] == 'B');
        assert(header.magic[1] == 'M');
        // std.debug.print("header: {}\n", .{header});

        const info: *const Info = @ptrCast(compressed_bytes[@sizeOf(Header)..]);
        // std.debug.print("info: {}\n", .{info});

        const width: u32 = @intCast(info.width);
        const height: u32 = @intCast(info.height);
        const raw = compressed_bytes[header.pixel_offset..][0..info.biSizeImage];
        // std.debug.print("file byte size: {d}\n", .{compressed_bytes.len});
        // std.debug.print("pixel buffer byte size: {d}\n", .{raw.len});

        return .{
            .raw = raw,
            .width = width,
            .height = height,
        };
    }
};
