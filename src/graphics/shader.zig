const std = @import("std");
const gl = @import("gl");

const global = @import("../global.zig");
const asset = @import("../asset.zig");

pub const ShaderProgramError = Shader.Error || Program.Error;

pub var manager: Manager = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    manager = Manager.init(allocator);
}

pub fn deinit() void {
    manager.deinit();
}

pub const Shader = struct {
    pub const Kind = enum(gl.@"enum") {
        vertex = gl.VERTEX_SHADER,
        fragment = gl.FRAGMENT_SHADER,
    };

    pub const Error = error{
        VertexCompilation,
        FragmentCompilation,
    };

    kind: Kind,
    asset_file: asset.AssetFile,
    id: gl.uint,
    compiled: bool = false,

    pub fn init(kind: Kind, path: []const u8) Shader {
        return Shader{
            .id = gl.CreateShader(@intFromEnum(kind)),
            .kind = kind,
            .asset_file = asset.AssetFile.init(path),
            .compiled = false,
        };
    }

    pub fn deinit(self: *Shader) void {
        self.asset_file.deinit();
        self.delete();
        self.* = undefined;
    }

    pub fn compile(self: *Shader) Error!void {
        const src = self.asset_file.read(global.scratch_buffer);
        // std.debug.print("compiling {s} shader\nsource: {s}\n\n", .{ @tagName(self.kind), src });
        gl.ShaderSource(self.id, 1, @ptrCast(&src), @ptrCast(&src.len));
        gl.CompileShader(self.id);

        var status: gl.int = undefined;
        gl.GetShaderiv(self.id, gl.COMPILE_STATUS, &status);
        self.compiled = status == gl.TRUE;

        if (!self.compiled) {
            switch (self.kind) {
                .vertex => return Error.VertexCompilation,
                .fragment => return Error.FragmentCompilation,
            }
        }
    }

    pub fn getInfoLog(self: *Shader) []const u8 {
        var len: gl.sizei = undefined;
        gl.GetShaderiv(self.id, gl.INFO_LOG_LENGTH, &len);
        const buf = global.scratch_buffer[0..@intCast(len)];
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
};

pub const Program = struct {
    pub const Error = error{
        Link,
    };

    pub const ShaderList = struct {
        vertex: ?Shader,
        fragment: ?Shader,
    };

    id: gl.uint,
    shader_list: ShaderList,
    linked: bool = false,

    pub fn init(list: ShaderList) Program {
        const program = Program{
            .id = gl.CreateProgram(),
            .shader_list = list,
        };

        if (program.shader_list.vertex) |*vertex| gl.AttachShader(program.id, vertex.id);
        if (program.shader_list.fragment) |*fragment| gl.AttachShader(program.id, fragment.id);

        return program;
    }

    /// compiles uncompiled-shaders, attaches all shaders to program, then links
    pub fn compileAndLink(self: *Program) ShaderProgramError!void {
        if (self.shader_list.vertex) |*vertex| try vertex.compile();
        if (self.shader_list.fragment) |*fragment| try fragment.compile();
        gl.LinkProgram(self.id);

        var status: gl.int = undefined;
        gl.GetProgramiv(self.id, gl.LINK_STATUS, &status);
        self.linked = status == gl.TRUE;

        if (!self.linked) {
            return Error.Link;
        }
    }

    pub fn getInfoLog(self: *Program) []const u8 {
        var len: gl.sizei = undefined;
        gl.GetProgramiv(self.id, gl.INFO_LOG_LENGTH, &len);
        const buf = global.scratch_buffer[0..@intCast(len)];
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

    pub fn dettach(self: *Program, shader_kind: Shader.Kind) void {
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

    pub fn defaultErrorHandler(self: *Program, err: ShaderProgramError) void {
        switch (err) {
            ShaderProgramError.VertexCompilation => {
                std.debug.print("failed to compile shader, error {s}", .{self.shader_list.vertex.?.getInfoLog()});
            },
            ShaderProgramError.FragmentCompilation => {
                std.debug.print("failed to compile shader, error {s}", .{self.shader_list.fragment.?.getInfoLog()});
            },
            ShaderProgramError.Link => {
                std.debug.print("failed to link shader program, error {s}", .{self.getInfoLog()});
            },
        }
    }
};

pub const Manager = struct {
    program_table: std.StringHashMap(Program),

    pub fn init(allocator: std.mem.Allocator) Manager {
        return Manager{
            .program_table = std.StringHashMap(Program).init(allocator),
        };
    }

    pub fn deinit(self: *Manager) void {
        self.program_table.deinit();
        self.* = undefined;
    }

    pub fn add(self: *Manager, name: []const u8, program: Program) void {
        self.program_table.put(name, program) catch {
            std.debug.print("failed to add to shader manager, program: {s}\n", .{name});
            unreachable;
        };
    }

    pub fn watch(self: *Manager) void {
        var iter = self.program_table.iterator();
        while (iter.next()) |entry| {
            const name = entry.key_ptr.*;
            const program = entry.value_ptr;

            var reload = false;
            if (program.shader_list.vertex) |*vertex| {
                if (vertex.asset_file.watch()) {
                    reload = true;
                }
            }
            if (program.shader_list.fragment) |*fragment| {
                if (fragment.asset_file.watch()) reload = true;
            }

            if (reload) {
                std.debug.print("reloading program: {s}\n", .{name});
                program.compileAndLink() catch |err| {
                    std.debug.print("failed to link program: {s}\n", .{name});
                    program.defaultErrorHandler(err);
                    return;
                };
            }
        }
    }
};
