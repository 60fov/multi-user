const std = @import("std");

const mu = @import("multi-user");
const platform = mu.platform;
const graphics = mu.graphics;
const gl = graphics.opengl.gl;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const width = 800;
    const height = 600;

    try platform.init(allocator, "opengl testing", width, height);
    defer platform.deinit();

    var major: [1]gl.int = undefined;
    var minor: [1]gl.int = undefined;
    gl.GetIntegerv(gl.MAJOR_VERSION, &major);
    gl.GetIntegerv(gl.MINOR_VERSION, &minor);
    std.debug.print("OpenGL Version {d}.{d}\n", .{ major[0], minor[0] });

    gl.Viewport((width - height) / 2, 0, height, height);

    var error_buffer: [4096]u8 = undefined;

    const vao_count = 1;
    const buffer_count = 1;
    const vertex_count = 6;
    var vaos: [vao_count]gl.uint = undefined;
    var buffers: [buffer_count]gl.uint = undefined;
    const vertices: [vertex_count][2]gl.float = .{
        .{ -2.0, -2.0 }, // Triangle 1
        .{ 0.85, -0.90 },
        .{ -2.0, 0.85 },
        .{ 2.0, -0.85 }, // Triangle 2
        .{ 2.0, 0.90 },
        .{ -2.5, 0.90 },
    };

    gl.CreateVertexArrays(1, &vaos);

    gl.CreateBuffers(1, &buffers);
    gl.NamedBufferStorage(buffers[0], @sizeOf(@TypeOf(vertices)), &vertices, 0);

    gl.VertexArrayVertexBuffer(vaos[0], 0, buffers[0], 0, @sizeOf(gl.float) * 2);

    gl.EnableVertexArrayAttrib(vaos[0], 0);
    gl.VertexArrayAttribFormat(vaos[0], 0, 2, gl.FLOAT, gl.FALSE, 0);
    gl.VertexArrayAttribBinding(vaos[0], 0, 0);

    var vert_shader = graphics.Shader{
        .kind = .vertex,
        .src = @embedFile("shaders/tri.vert"),
    };

    if (!vert_shader.load()) {
        const len: usize = @intCast(vert_shader.getInfoLogLen());
        const log = vert_shader.getInfoLog(error_buffer[0..len]);
        std.debug.print("shader failed to load {s}\n", .{log});
        return;
    }
    defer vert_shader.delete();

    var frag_shader = graphics.Shader{
        .kind = .fragment,
        .src = @embedFile("shaders/tri.frag"),
    };
    defer frag_shader.delete();

    if (!frag_shader.load()) {
        const len: usize = @intCast(frag_shader.getInfoLogLen());
        const log = frag_shader.getInfoLog(error_buffer[0..len]);
        std.debug.print("shader failed to load {s}\n", .{log});
        return;
    }

    var program = graphics.ShaderProgram{
        .vertex = vert_shader,
        .fragment = frag_shader,
    };
    defer program.delete();

    if (!program.load()) {
        const len: usize = @intCast(program.getInfoLogLen());
        const log = program.getInfoLog(error_buffer[0..len]);
        std.debug.print("program failed to load {s}\n", .{log});
        return;
    }

    program.use();

    while (!platform.shouldQuit()) {
        platform.poll();
        gl.ClearColor(0.18, 0.143, 0.155, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.BindVertexArray(vaos[0]);
        gl.DrawArrays(gl.TRIANGLES, 0, vertex_count);

        platform.present();
    }
}
