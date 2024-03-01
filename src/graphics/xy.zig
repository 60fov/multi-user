const std = @import("std");
const gl = @import("gl");

const Shader = @import("shader.zig");

var width: i32 = undefined;
var height: i32 = undefined;
var aspect: f32 = undefined;

const rect_vertices = [_]gl.float{
    -1, 1,
    -1, -1,
    1,  -1,
    1,  1,
};

const Instance = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    r: u8,
    g: u8,
    b: u8,
};

const rect_indices = [_]gl.ubyte{ 0, 1, 2, 0, 2, 3 };

const vao_count = 1;
var vaos: [vao_count]gl.uint = undefined;

const buf_idx_vbo = 0;
const buf_idx_ebo = 1;
const buf_idx_ibo = 2;
const buffer_count = 3;
var buffers: [buffer_count]gl.uint = undefined;

var vao: gl.uint = undefined;
var vbo: gl.uint = undefined; // vertex buffer
var ebo: gl.uint = undefined; // element buffer (indices)
var ibo: gl.uint = undefined; // instance buffer

const max_instance_count = 1000;
const instance_buffer_size = max_instance_count * @sizeOf(Instance);
var instance_data: [max_instance_count]Instance = undefined;
var draw_idx: u32 = 0;

const vs_src = @embedFile("shaders/xy.vert");
const fs_src = @embedFile("shaders/xy.frag");
var debug_buffer: [4096]u8 = undefined;
var program: Shader.Program = undefined;

pub fn init() !void {
    gl.Enable(gl.DEBUG_OUTPUT);
    gl.DebugMessageCallback(debug_callback, null);

    gl.CreateVertexArrays(vao_count, @ptrCast(&vaos));
    gl.CreateBuffers(buffer_count, &buffers);

    vao = vaos[0];
    vbo = buffers[buf_idx_vbo];
    ebo = buffers[buf_idx_ebo];
    ibo = buffers[buf_idx_ibo];

    gl.NamedBufferStorage(vbo, @sizeOf(@TypeOf(rect_vertices)), &rect_vertices, 0);
    gl.NamedBufferStorage(ebo, @sizeOf(@TypeOf(rect_indices)), &rect_indices, 0);
    gl.NamedBufferStorage(ibo, instance_buffer_size, null, gl.DYNAMIC_STORAGE_BIT);

    gl.VertexArrayVertexBuffer(vao, 0, vbo, 0, 2 * @sizeOf(gl.float));
    gl.VertexArrayVertexBuffer(vao, 1, ibo, 0, @sizeOf(Instance));
    gl.VertexArrayBindingDivisor(vao, 1, 1);
    gl.VertexArrayElementBuffer(vao, ebo);

    // vertex pos
    gl.EnableVertexArrayAttrib(vao, 0);
    gl.VertexArrayAttribFormat(vao, 0, 2, gl.FLOAT, gl.FALSE, 0);

    // instance pos
    gl.EnableVertexArrayAttrib(vao, 1);
    gl.VertexArrayAttribFormat(vao, 1, 2, gl.INT, gl.FALSE, @offsetOf(Instance, "x"));
    gl.VertexArrayAttribBinding(vao, 1, 1);

    // instance size
    gl.EnableVertexArrayAttrib(vao, 2);
    gl.VertexArrayAttribFormat(vao, 2, 2, gl.INT, gl.FALSE, @offsetOf(Instance, "w"));
    gl.VertexArrayAttribBinding(vao, 2, 1);

    // instance color
    gl.EnableVertexArrayAttrib(vao, 3);
    gl.VertexArrayAttribFormat(vao, 3, 3, gl.UNSIGNED_BYTE, gl.TRUE, @offsetOf(Instance, "r"));
    gl.VertexArrayAttribBinding(vao, 3, 1);

    program = Shader.Program.init(.{
        .vertex = Shader.init(.vertex, vs_src),
        .fragment = Shader.init(.fragment, fs_src),
    });

    program.link() catch |err| {
        switch (err) {
            Shader.ShaderProgramError.VertexCompilation => {
                std.debug.print(
                    "failed to compile shader, error {s}",
                    .{program.shader_list.vertex.?.getInfoLog()},
                );
            },
            Shader.ShaderProgramError.FragmentCompilation => {
                std.debug.print(
                    "failed to compile shader, error {s}",
                    .{program.shader_list.fragment.?.getInfoLog()},
                );
            },
            Shader.ShaderProgramError.Link => {
                std.debug.print(
                    "failed to link shader program, error {s}",
                    .{program.getInfoLog()},
                );
            },
        }
        return err;
    };
}

pub fn clear() void {
    gl.ClearColor(0.1, 0.1, 0.2, 1);
    gl.Clear(gl.COLOR_BUFFER_BIT);
}

pub fn deinit() void {
    program.delete();
}

pub fn viewport(window_width: i32, window_height: i32, pixel_ratio: f32) void {
    width = window_width;
    height = window_height;
    aspect = pixel_ratio;
    gl.Viewport(0, 0, window_width, window_height);
}

pub fn rect(x: i32, y: i32, w: i32, h: i32, r: u8, g: u8, b: u8) void {
    if (draw_idx >= max_instance_count) {
        flush();
    }
    const offset = @sizeOf(Instance) * draw_idx;
    const data = Instance{
        .x = x,
        .y = y,
        .w = w,
        .h = h,
        .r = r,
        .g = g,
        .b = b,
    };
    gl.NamedBufferSubData(ibo, offset, @sizeOf(Instance), &data);
    draw_idx += 1;
}

pub fn flush() void {
    program.use();
    gl.BindVertexArray(vao);
    gl.DrawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_BYTE, null, @intCast(draw_idx));
    draw_idx = 0;
}

pub fn debug_callback(
    source: gl.@"enum",
    @"type": gl.@"enum",
    id: gl.uint,
    severity: gl.@"enum",
    length: gl.sizei,
    message: [*:0]const gl.char,
    userParam: ?*const anyopaque,
) callconv(gl.APIENTRY) void {
    _ = length;
    _ = userParam;
    const src_str = switch (source) {
        gl.DEBUG_SOURCE_API => "API",
        gl.DEBUG_SOURCE_WINDOW_SYSTEM => "WINDOW SYSTEM",
        gl.DEBUG_SOURCE_SHADER_COMPILER => "SHADER COMPILER",
        gl.DEBUG_SOURCE_THIRD_PARTY => "THIRD PARTY",
        gl.DEBUG_SOURCE_APPLICATION => "APPLICATION",
        gl.DEBUG_SOURCE_OTHER => "OTHER",
        else => "???",
    };

    const type_str = switch (@"type") {
        gl.DEBUG_TYPE_ERROR => "ERROR",
        gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR => "DEPRECATED_BEHAVIOR",
        gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR => "UNDEFINED_BEHAVIOR",
        gl.DEBUG_TYPE_PORTABILITY => "PORTABILITY",
        gl.DEBUG_TYPE_PERFORMANCE => "PERFORMANCE",
        gl.DEBUG_TYPE_MARKER => "MARKER",
        gl.DEBUG_TYPE_OTHER => "OTHER",
        else => "???",
    };

    const severity_str = switch (severity) {
        gl.DEBUG_SEVERITY_NOTIFICATION => "NOTIFICATION",
        gl.DEBUG_SEVERITY_LOW => "LOW",
        gl.DEBUG_SEVERITY_MEDIUM => "MEDIUM",
        gl.DEBUG_SEVERITY_HIGH => "HIGH",
        else => "???",
    };

    std.debug.print("{s}, {s}, {s}, {d}: {s}\n", .{ src_str, type_str, severity_str, id, message });
}
