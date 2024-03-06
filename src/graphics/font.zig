const std = @import("std");

const gl = @import("gl");
const texture = @import("texture.zig");
const image = @import("../image.zig");

const atlas_size = 256;

pub const Sdf = struct {
    pub const AtlasEntry = struct {
        x: i32,
        y: i32,
        w: i32,
        h: i32,
        originX: i32,
        originY: i32,
        advance: i32,
        loaded: bool,
    };

    pub const Atlas = struct {
        size: i32,
        width: i32,
        height: i32,
        glyph_max_width: i32,
        glyph_max_height: i32,
        rects: []AtlasEntry,

        pub fn deinit(self: *Atlas, allocator: std.mem.Allocator) void {
            allocator.free(self.rects);
            self.* = undefined;
        }
    };

    texture: gl.uint = undefined,
    atlas: Atlas,

    pub fn load(self: *Sdf, bytes: []u8, texture_width: usize, texture_height: usize) void {
        // todo get from atlas
        const glyph_w: gl.sizei = @intCast(self.atlas.glyph_max_width);
        const glyph_h: gl.sizei = @intCast(self.atlas.glyph_max_height);

        var tex_id: gl.uint = undefined;
        gl.CreateTextures(gl.TEXTURE_2D_ARRAY, 1, @ptrCast(&tex_id));
        gl.TextureStorage3D(
            tex_id,
            1,
            gl.RGBA8,
            glyph_w,
            glyph_h,
            @intCast(self.atlas.rects.len),
        );

        {
            var temp_id: gl.uint = undefined;
            gl.CreateTextures(gl.TEXTURE_2D, 1, @ptrCast(&temp_id));
            // defer gl.DeleteTextures(1, @ptrCast(&temp_id));

            const w: gl.sizei = @intCast(texture_width);
            const h: gl.sizei = @intCast(texture_height);
            gl.TextureStorage2D(temp_id, 1, gl.RGBA8, w, h);
            gl.TextureSubImage2D(temp_id, 0, 0, 0, w, h, gl.RGB, gl.UNSIGNED_BYTE, bytes.ptr);

            for (0..self.atlas.rects.len) |i| {
                const entry = self.atlas.rects[i];
                if (entry.loaded) {
                    const src_x = entry.x;
                    const src_y = entry.y;

                    gl.CopyImageSubData(
                        temp_id,
                        gl.TEXTURE_2D,
                        0,
                        src_x,
                        h - src_y - entry.h,
                        0,
                        tex_id,
                        gl.TEXTURE_2D_ARRAY,
                        0,
                        0,
                        0,
                        @intCast(i),
                        @intCast(entry.w),
                        @intCast(entry.h),
                        1,
                    );
                }
            }
        }

        self.texture = tex_id;
    }

    pub fn parseAtlas(allocator: std.mem.Allocator, bytes: []const u8) !Atlas {
        const json = std.json;
        const parsed = try std.json.parseFromSlice(json.Value, allocator, bytes, .{});
        const root = parsed.value;
        const characters = root.object.get("characters").?;
        const keys = characters.object.keys();

        var atlas = Atlas{
            .size = @intCast(root.object.get("size").?.integer),
            .width = @intCast(root.object.get("width").?.integer),
            .height = @intCast(root.object.get("height").?.integer),
            .glyph_max_width = 0,
            .glyph_max_height = 0,
            .rects = try allocator.alloc(AtlasEntry, atlas_size),
        };

        for (atlas.rects) |*rect| {
            rect.loaded = false;
        }

        for (keys) |key| {
            std.debug.assert(key.len == 1);
            const data = characters.object.get(key).?;
            const char = key[0];
            const entry = AtlasEntry{
                .loaded = true,
                .x = @intCast(data.object.get("x").?.integer),
                .y = @intCast(data.object.get("y").?.integer),
                .w = @intCast(data.object.get("width").?.integer),
                .h = @intCast(data.object.get("height").?.integer),
                .originX = @intCast(data.object.get("originX").?.integer),
                .originY = @intCast(data.object.get("originY").?.integer),
                .advance = @intCast(data.object.get("advance").?.integer),
            };
            atlas.rects[char] = entry;
            atlas.glyph_max_width = @max(entry.w, atlas.glyph_max_width);
            atlas.glyph_max_height = @max(entry.h, atlas.glyph_max_height);
        }
        return atlas;
    }
};
