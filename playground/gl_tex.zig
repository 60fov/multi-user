const std = @import("std");
const mu = @import("multi-user");
const platform = mu.platform;
const graphics = mu.graphics;
const image = mu.image;

const gl = graphics.opengl.gl;
const Shader = graphics.Shader;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const width = 800;
    const height = 600;

    try platform.init(allocator, "opengl testing", width, height);
    defer platform.deinit();

    // const sdf_bmp = image.Bmp.create(@embedFile("fonts/crystal/crystal_sdf_32_5.bmp"));
    const sdf_bmp = image.Bmp.create(@embedFile("fonts/crystal/crystal_sdf_32_5.bmp"));

    const verts = [_]Vertex{
        v(-0.75, 0.75, -0.5, 1.5),
        v(-0.75, -0.75, -0.5, -0.5),
        v(0.75, -0.75, 1.5, -0.5),
        v(0.75, 0.75, 1.5, 1.5),
    };

    const indis = [_]gl.ubyte{ 0, 1, 2, 0, 2, 3 };

    var major: [1]gl.int = undefined;
    var minor: [1]gl.int = undefined;
    gl.GetIntegerv(gl.MAJOR_VERSION, &major);
    gl.GetIntegerv(gl.MINOR_VERSION, &minor);
    std.debug.print("OpenGL Version {d}.{d}\n", .{ major[0], minor[0] });

    gl.Viewport(0, 0, width, height);

    var vao: gl.uint = undefined;
    gl.CreateVertexArrays(1, @ptrCast(&vao));

    var buffers: struct { vbo: gl.uint, ibo: gl.uint } = undefined;
    gl.CreateBuffers(2, @ptrCast(&buffers));
    gl.NamedBufferStorage(buffers.vbo, @sizeOf(@TypeOf(verts)), @ptrCast(&verts), 0);
    gl.NamedBufferStorage(buffers.ibo, indis.len * @sizeOf(@TypeOf(indis)), @ptrCast(&indis), 0);

    gl.VertexArrayVertexBuffer(vao, 0, buffers.vbo, 0, @sizeOf(Vertex));
    gl.VertexArrayElementBuffer(vao, buffers.ibo);

    gl.EnableVertexArrayAttrib(vao, 0);
    gl.VertexArrayAttribBinding(vao, 0, 0);
    gl.VertexArrayAttribFormat(vao, 0, 2, gl.FLOAT, gl.FALSE, @offsetOf(Vertex, "pos"));

    gl.EnableVertexArrayAttrib(vao, 1);
    gl.VertexArrayAttribBinding(vao, 1, 0);
    gl.VertexArrayAttribFormat(vao, 1, 2, gl.FLOAT, gl.FALSE, @offsetOf(Vertex, "uv"));

    var program = Shader.Program.init(.{
        .vertex = Shader.init(.vertex, @embedFile("shaders/gl_tex.vert")),
        .fragment = Shader.init(.fragment, @embedFile("shaders/gl_tex.frag")),
    });

    // TODO do we like this?
    program.link() catch |err| {
        switch (err) {
            Shader.ShaderProgramError.VertexCompilation => {
                std.debug.print("failed to compile vertex shader, error {s}", .{program.shader_list.vertex.?.getInfoLog()});
            },
            Shader.ShaderProgramError.FragmentCompilation => {
                std.debug.print("failed to compile fragment shader, error {s}", .{program.shader_list.fragment.?.getInfoLog()});
            },
            Shader.ShaderProgramError.Link => {
                std.debug.print("failed to link shader program, error {s}", .{program.getInfoLog()});
            },
        }
        return err;
    };

    var tex_id: gl.uint = undefined;
    gl.CreateTextures(gl.TEXTURE_2D, 1, @ptrCast(&tex_id));

    gl.TextureParameteri(tex_id, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER);
    gl.TextureParameteri(tex_id, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);
    gl.TextureParameteri(tex_id, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TextureParameteri(tex_id, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    const w: gl.sizei = @intCast(sdf_bmp.width);
    const h: gl.sizei = @intCast(sdf_bmp.height);
    gl.TextureStorage2D(tex_id, 1, gl.RGBA8, w, h);
    gl.TextureSubImage2D(tex_id, 0, 0, 0, w, h, gl.RGB, gl.UNSIGNED_BYTE, sdf_bmp.raw.ptr);

    const t_unit = 0;
    gl.BindTextureUnit(t_unit, tex_id);
    gl.ProgramUniform1i(program.id, gl.GetUniformLocation(program.id, "tex1"), t_unit);
    // program.setInt("tex1", t_uint);

    program.use();
    gl.BindVertexArray(vao);

    while (!platform.shouldQuit()) {
        platform.poll();

        gl.ClearColor(0.18, 0.143, 0.155, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_BYTE, 0);

        platform.present();
    }
}

const Vertex = struct {
    pos: struct { x: f32, y: f32 },
    uv: struct { u: f32, v: f32 },
};

fn v(x: f32, y: f32, z: f32, w: f32) Vertex {
    return Vertex{
        .pos = .{ .x = x, .y = y },
        .uv = .{ .u = z, .v = w },
    };
}
