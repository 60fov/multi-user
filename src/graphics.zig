const std = @import("std");

pub const opengl = @import("graphics/opengl.zig");
pub const Shader = @import("graphics/shader.zig");
pub const xy = @import("graphics/xy.zig");

const gl = opengl.gl;

pub const ShaderProgram = struct {
    vertex: Shader,
    fragment: Shader,
    id: gl.uint = undefined,
    linked: bool = false,

    pub fn load(self: *ShaderProgram) bool {
        self.id = gl.CreateProgram();
        gl.AttachShader(self.id, self.vertex.id);
        gl.AttachShader(self.id, self.fragment.id);
        gl.LinkProgram(self.id);
        var linked: gl.int = undefined;
        gl.GetProgramiv(self.id, gl.LINK_STATUS, &linked);
        self.linked = linked == gl.TRUE;
        return self.linked;
    }

    pub fn delete(self: *ShaderProgram) void {
        gl.DeleteProgram(self.id);
    }

    pub fn use(self: *ShaderProgram) void {
        gl.UseProgram(self.id);
    }

    pub fn getInfoLogLen(self: *ShaderProgram) gl.sizei {
        var len: gl.sizei = undefined;
        gl.GetProgramiv(self.id, gl.INFO_LOG_LENGTH, &len);
        return len;
    }

    pub fn getInfoLog(self: *ShaderProgram, buffer: []u8) []u8 {
        var len: gl.sizei = undefined;
        gl.GetProgramInfoLog(self.id, @intCast(buffer.len), &len, buffer.ptr);
        return buffer[0..@intCast(len)];
    }
};

test {
    const platform = @import("platform.zig");
    const width = 800;
    const height = 600;
    try platform.init(std.testing.allocator, "opengl testing", width, height);
    defer platform.deinit();

    var major: [1]gl.int = undefined;
    var minor: [1]gl.int = undefined;
    gl.GetIntegerv(gl.MAJOR_VERSION, &major);
    gl.GetIntegerv(gl.MINOR_VERSION, &minor);
    try std.testing.expectEqual(major[0], 4);
    try std.testing.expectEqual(minor[0], 6);

    gl.Viewport(0, 0, width, height);

    while (!platform.shouldQuit()) {
        platform.poll();
        gl.ClearColor(0.18, 0.143, 0.155, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        platform.present();
    }
}
