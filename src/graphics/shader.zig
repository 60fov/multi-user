const std = @import("std");
const gl = @import("gl");

const Shader = @This();

var debug_buffer: [4096]u8 = undefined;

pub const Kind = enum(gl.@"enum") {
    vertex = gl.VERTEX_SHADER,
    fragment = gl.FRAGMENT_SHADER,
};

pub const ShaderError = error{
    VertexCompilation,
    FragmentCompilation,
};

pub const ProgramError = error{
    Link,
};

pub const ShaderProgramError = ShaderError || ProgramError;

kind: Kind,
src: []const u8,
id: gl.uint,
compiled: bool = false,

pub fn init(kind: Kind, source: []const u8) Shader {
    return Shader{
        .id = gl.CreateShader(@intFromEnum(kind)),
        .kind = kind,
        .src = source,
        .compiled = false,
    };
}

pub fn compile(self: *Shader) ShaderError!void {
    gl.ShaderSource(self.id, 1, @ptrCast(&self.src), null);
    gl.CompileShader(self.id);

    var status: gl.int = undefined;
    gl.GetShaderiv(self.id, gl.COMPILE_STATUS, &status);
    self.compiled = status == gl.TRUE;

    if (!self.compiled) {
        switch (self.kind) {
            .vertex => return ShaderError.VertexCompilation,
            .fragment => return ShaderError.FragmentCompilation,
        }
    }
}

pub fn getInfoLog(self: *Shader) []const u8 {
    var len: gl.sizei = undefined;
    gl.GetShaderiv(self.id, gl.INFO_LOG_LENGTH, &len);
    const buf = debug_buffer[0..@intCast(len)];
    gl.GetShaderInfoLog(self.id, @intCast(buf.len), null, buf.ptr);
    return buf;
}

/// don't forget to free this
pub fn getInfoLogAlloc(self: *Shader, allocator: std.mem.Allocator) ![]const u8 {
    var len: gl.sizei = undefined;
    gl.GetShaderiv(self.id, gl.INFO_LOG_LENGTH, &len);
    const buf = try allocator.alloc(u8, @intCast(len));
    gl.GetShaderInfoLog(self.id, @intCast(buf.len), null, buf.ptr);
    return buf;
}

// TODO thnk about this
pub fn delete(self: *Shader) void {
    gl.DeleteShader(self.id);
    self.id = undefined;
    self.kind = undefined;
}

pub const Program = struct {
    pub const ShaderList = struct {
        vertex: ?Shader,
        fragment: ?Shader,
    };

    id: gl.uint,
    shader_list: ShaderList,
    linked: bool = false,

    pub fn init(list: ShaderList) Program {
        return Program{
            .id = gl.CreateProgram(),
            .shader_list = list,
        };
    }

    /// compiles uncompiled-shaders, attaches all shaders to program, then links
    pub fn link(self: *Program) ShaderProgramError!void {
        if (self.shader_list.vertex) |*vertex| {
            if (!vertex.compiled) try vertex.compile();
            gl.AttachShader(self.id, vertex.id);
        }
        if (self.shader_list.fragment) |*fragment| {
            if (!fragment.compiled) try fragment.compile();
            gl.AttachShader(self.id, fragment.id);
        }
        gl.LinkProgram(self.id);

        var status: gl.int = undefined;
        gl.GetProgramiv(self.id, gl.LINK_STATUS, &status);
        self.linked = status == gl.TRUE;

        if (!self.linked) {
            return ProgramError.Link;
        }
    }

    pub fn getInfoLog(self: *Program) []const u8 {
        var len: gl.sizei = undefined;
        gl.GetProgramiv(self.id, gl.INFO_LOG_LENGTH, &len);
        const buf = debug_buffer[0..@intCast(len)];
        gl.GetProgramInfoLog(self.id, @intCast(buf.len), null, buf.ptr);
        return buf;
    }

    /// don't forget to free this
    pub fn getInfoLogAlloc(self: *Shader, allocator: std.mem.Allocator) ![]const u8 {
        var len: gl.sizei = undefined;
        gl.GetProgramiv(self.id, gl.INFO_LOG_LENGTH, &len);
        const buf = try allocator.alloc(u8, @intCast(len));
        gl.GetProgramInfoLog(self.id, @intCast(buf.len), null, buf.ptr);
        return buf;
    }

    pub fn use(self: *Program) void {
        gl.UseProgram(self.id);
    }

    pub fn dettach(self: *Program, shader_kind: Kind) void {
        switch (shader_kind) {
            .vertex => if (self.shader_list.vertex) |vertex| gl.DetachShader(self.id, vertex.id),
            .fragment => if (self.shader_list.fragment) |fragment| gl.DetachShader(self.id, fragment.id),
        }
    }

    // TODO think about this
    // trying to use after deletion will cause UB unless self.* = undefined
    // delete is also just a flag until program is unlinked
    // could keep other things around until deinit...
    pub fn delete(self: *Program) void {
        gl.DeleteProgram(self.id);
        self.id = undefined;
    }
};
