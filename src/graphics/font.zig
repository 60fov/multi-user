const std = @import("std");

const gl = @import("gl");
const image = @import("../image.zig");
const asset = @import("../asset.zig");
const global = @import("../global.zig");

const atlas_size = 256;

const FontManager = asset.Manager(Sdf);
pub var manager: FontManager = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    manager = FontManager.init(allocator, Sdf.watchAndReload);
}

pub fn deinit() void {
    manager.deinit();
}

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
        asset: asset.AssetFile,
        size: i32 = undefined,
        width: i32 = undefined,
        height: i32 = undefined,
        glyph_max_width: i32 = undefined,
        glyph_max_height: i32 = undefined,
        rects: []AtlasEntry = undefined,

        pub fn deinit(self: *Atlas, allocator: std.mem.Allocator) void {
            allocator.free(self.rects);
            self.* = undefined;
        }

        pub fn load(self: *Atlas, allocator: std.mem.Allocator) !void {
            const bytes = self.asset.read(global.scratch_buffer);

            const json = std.json;
            const parsed = try std.json.parseFromSlice(json.Value, allocator, bytes, .{});
            const root = parsed.value;
            const characters = root.object.get("characters").?;
            const keys = characters.object.keys();

            self.size = @intCast(root.object.get("size").?.integer);
            self.width = @intCast(root.object.get("width").?.integer);
            self.height = @intCast(root.object.get("height").?.integer);
            self.glyph_max_width = 0;
            self.glyph_max_height = 0;
            self.rects = try allocator.alloc(AtlasEntry, atlas_size);

            for (self.rects) |*rect| {
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
                self.rects[char] = entry;
                self.glyph_max_width = @max(entry.w, self.glyph_max_width);
                self.glyph_max_height = @max(entry.h, self.glyph_max_height);
            }
        }
    };

    pub const Texture = struct {
        id: gl.uint = undefined,
        asset: asset.AssetFile,

        // TODO error check texture load
        pub fn load(self: *Texture, atlas: Atlas) void {
            const tex_bmp = image.Bmp.create(self.asset.read(global.scratch_buffer));

            const bytes: []u8 = @constCast(tex_bmp.raw);
            const texture_width: usize = tex_bmp.width;
            const texture_height: usize = tex_bmp.height;

            const glyph_w: gl.sizei = @intCast(atlas.glyph_max_width);
            const glyph_h: gl.sizei = @intCast(atlas.glyph_max_height);

            var tex_id: gl.uint = undefined;
            gl.CreateTextures(gl.TEXTURE_2D_ARRAY, 1, @ptrCast(&tex_id));
            gl.TextureStorage3D(
                tex_id,
                1,
                gl.RGBA8,
                glyph_w,
                glyph_h,
                @intCast(atlas.rects.len),
            );

            {
                var temp_id: gl.uint = undefined;
                gl.CreateTextures(gl.TEXTURE_2D, 1, @ptrCast(&temp_id));
                // defer gl.DeleteTextures(1, @ptrCast(&temp_id));

                const w: gl.sizei = @intCast(texture_width);
                const h: gl.sizei = @intCast(texture_height);
                gl.TextureStorage2D(temp_id, 1, gl.RGBA8, w, h);
                gl.TextureSubImage2D(temp_id, 0, 0, 0, w, h, gl.RGB, gl.UNSIGNED_BYTE, bytes.ptr);

                for (0..atlas.rects.len) |i| {
                    const entry = atlas.rects[i];
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
            self.id = tex_id;
        }
    };

    texture: Texture,
    atlas: Atlas,

    pub fn init(path: []const u8) !Sdf {
        // load atlas
        var atlas_asset: asset.AssetFile = undefined;
        {
            const file_path = try std.mem.join(global.allocator(), "", &.{ path, ".json" });
            defer global.allocator().free(file_path);
            atlas_asset = asset.AssetFile.init(file_path);
        }
        var atlas = Atlas{ .asset = atlas_asset };
        try atlas.load(global.allocator());

        // load texture
        var tex_asset: asset.AssetFile = undefined;
        {
            const file_path = try std.mem.join(global.allocator(), "", &.{ path, ".bmp" });
            defer global.allocator().free(file_path);
            tex_asset = asset.AssetFile.init(file_path);
        }
        var texture = Texture{ .asset = tex_asset };
        texture.load(atlas);

        return Sdf{
            .texture = texture,
            .atlas = atlas,
        };
    }

    pub fn getTextWidth(self: Sdf, text: []const u8) i32 {
        var advance: i32 = 0;
        for (text) |c| {
            const glyph = self.atlas.rects[c];
            // .x = @as(f32, @floatFromInt(x + advance - glyph.originX)),
            // .y = @as(f32, @floatFromInt(y - (glyph.h - glyph.originY))),
            advance += glyph.advance;
        }
        return advance;
    }

    pub fn getHeight(self: Sdf) i32 {
        return self.atlas.glyph_max_height;
    }

    pub fn watchAndReload(self: *Sdf) void {
        const atlas_change = self.atlas.asset.watch();
        const tex_change = self.texture.asset.watch();
        if (atlas_change or tex_change) {
            self.atlas.load(global.allocator()) catch {
                std.debug.print("failed to reload font atlas, file: {s}\n", .{self.atlas.asset.path});
            };
            self.texture.load(self.atlas);
        }
    }
};
