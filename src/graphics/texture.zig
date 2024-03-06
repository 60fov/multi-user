const gl = @import("gl");

const Texture = @This();

pub const Kind = enum(gl.@"enum") {
    texture_2d = gl.TEXTURE_2D,
    texture_2d_array = gl.TEXTURE_2D_ARRAY,
};

pub const Parameter = enum(gl.@"enum") {
    linear = gl.LINEAR,
    nearest = gl.NEAREST,
};

// TODO prob remove from namespace in favor of WrapCoordinate
pub const wrap = struct {
    pub const Coordinate = enum(gl.@"enum") {
        wrap_s = gl.TEXTURE_WRAP_S,
        wrap_t = gl.TEXTURE_WRAP_T,
    };

    pub const Value = enum(gl.@"enum") {
        clamp_to_edge = gl.CLAMP_TO_EDGE,
        clamp_to_border = gl.CLAMP_TO_BORDER,
        mirrored_repeat = gl.MIRRORED_REPEAT,
        repeat = gl.REPEAT,
        mirror_clamp_to_edge = gl.MIRROR_CLAMP_TO_EDGE,
    };
};

id: gl.uint,

pub fn create(kind: Kind) Texture {
    const id: gl.uint = undefined;
    gl.CreateTextures(@intFromEnum(kind), 1, @ptrCast(&id));
    Texture{
        .id = id,
    };
}

pub fn setWrap(self: Texture, coord: wrap.Coordinate, value: wrap.Value) void {
    gl.TextureParameteri(self.id, @intFromEnum(coord), @intFromEnum(value));
}
