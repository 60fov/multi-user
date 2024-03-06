const std = @import("std");
const mu = @import("multi-user");
const platform = mu.platform;
const graphics = mu.graphics;
const image = mu.image;

const gl = graphics.opengl.gl;
const Shader = graphics.Shader;

var vao: gl.uint = undefined;
var buffers: struct {
    vbo: gl.uint,
    ibo: gl.uint,
    sbo_info: gl.uint,
    sbo_inst: gl.uint,
} = undefined;
const buffer_count = @typeInfo(@TypeOf(buffers)).Struct.fields.len;

var draw_idx: usize = 0;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const width = 800;
    const height = 600;

    try platform.init(allocator, "opengl testing", width, height);
    defer platform.deinit();

    const bmp = image.Bmp.create(@embedFile("fonts/hack/sdf_32_5.bmp"));
    const atlas_json_bytes = @embedFile("fonts/hack/sdf_32_5.json");

    const verts = [_]Vertex{
        v(0, 1, 0, 1),
        v(0, 0, 0, 0),
        v(1, 0, 1, 0),
        v(1, 1, 1, 1),
    };

    const indis = [_]gl.ubyte{ 0, 1, 2, 0, 2, 3 };

    var major: [1]gl.int = undefined;
    var minor: [1]gl.int = undefined;
    gl.GetIntegerv(gl.MAJOR_VERSION, &major);
    gl.GetIntegerv(gl.MINOR_VERSION, &minor);
    std.debug.print("OpenGL Version {d}.{d}\n", .{ major[0], minor[0] });

    gl.Viewport(0, 0, width, height);

    gl.CreateVertexArrays(1, @ptrCast(&vao));

    gl.CreateBuffers(buffer_count, @ptrCast(&buffers));
    gl.NamedBufferStorage(buffers.vbo, @sizeOf(@TypeOf(verts)), @ptrCast(&verts), 0);
    gl.NamedBufferStorage(buffers.ibo, indis.len * @sizeOf(@TypeOf(indis)), @ptrCast(&indis), 0);
    gl.NamedBufferStorage(buffers.sbo_info, @sizeOf(ShaderStorageInfo), null, gl.DYNAMIC_STORAGE_BIT);
    gl.NamedBufferStorage(buffers.sbo_inst, @sizeOf(ShaderStorageInstance), null, gl.DYNAMIC_STORAGE_BIT);

    gl.VertexArrayVertexBuffer(vao, 0, buffers.vbo, 0, @sizeOf(Vertex));
    gl.VertexArrayElementBuffer(vao, buffers.ibo);
    // NOTE not bound the the vao
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, buffers.sbo_info);
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, buffers.sbo_inst);

    gl.EnableVertexArrayAttrib(vao, 0);
    gl.VertexArrayAttribBinding(vao, 0, 0);
    gl.VertexArrayAttribFormat(vao, 0, 2, gl.FLOAT, gl.FALSE, @offsetOf(Vertex, "pos"));

    gl.EnableVertexArrayAttrib(vao, 1);
    gl.VertexArrayAttribBinding(vao, 1, 0);
    gl.VertexArrayAttribFormat(vao, 1, 2, gl.FLOAT, gl.FALSE, @offsetOf(Vertex, "uv"));

    var program = Shader.Program.init(.{
        .vertex = Shader.init(.vertex, @embedFile("shaders/sdf_text.vert")),
        .fragment = Shader.init(.fragment, @embedFile("shaders/sdf_text.frag")),
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

    var font_crystal = graphics.font.Sdf{
        .atlas = try graphics.font.Sdf.parseAtlas(allocator, atlas_json_bytes),
    };
    font_crystal.load(@constCast(bmp.raw), bmp.width, bmp.height);
    defer font_crystal.atlas.deinit(allocator);

    var ss_info = ShaderStorageInfo{
        .screen_width = width,
        .screen_height = height,
        .font_width = @floatFromInt(font_crystal.atlas.glyph_max_width),
        .font_height = @floatFromInt(font_crystal.atlas.glyph_max_height),
    };

    gl.NamedBufferSubData(buffers.sbo_info, 0, @sizeOf(ShaderStorageInfo), @ptrCast(&ss_info));

    const t_unit = 0;
    gl.BindTextureUnit(t_unit, font_crystal.texture);
    const font_tex_loc = gl.GetUniformLocation(program.id, "font_tex");
    gl.ProgramUniform1i(program.id, font_tex_loc, 0);

    program.use();
    gl.BindVertexArray(vao);

    while (!platform.shouldQuit()) {
        platform.poll();

        gl.ClearColor(0.18, 0.143, 0.155, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        draw_idx = 0;

        draw_text("my b didn't know you were drippy like that", font_crystal, 0, 0, 255, 0, 0);
        draw_text("text", font_crystal, 200, 300, 0, 255, 0);
        draw_text("fdjkal;fjdkl;", font_crystal, 500, 150, 0, 0, 255);

        gl.DrawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_BYTE, null, @intCast(draw_idx));

        platform.present();
    }
}

fn draw_text(text: []const u8, font: graphics.font.Sdf, x: f32, y: f32, r: u8, g: u8, b: u8) void {
    const size = @sizeOf(Instance);
    var advance: i32 = 0;
    for (text) |c| {
        const offset = draw_idx * size;
        const glyph = font.atlas.rects[c];
        // advance -= glyph.originX;
        var data = Instance{
            .x = x + @as(f32, @floatFromInt(advance - glyph.originX)),
            .y = y - @as(f32, @floatFromInt(glyph.h - glyph.originY)),
            .w = @floatFromInt(glyph.w),
            .h = @floatFromInt(glyph.h),
            .r = @as(f32, @floatFromInt(r)) / 255,
            .g = @as(f32, @floatFromInt(g)) / 255,
            .b = @as(f32, @floatFromInt(b)) / 255,
            .a = 1,
            .char = c,
        };
        // std.debug.print("inst {}\n", .{data});
        advance += glyph.advance;
        gl.NamedBufferSubData(buffers.sbo_inst, @intCast(offset), size, @ptrCast(&data));
        draw_idx += 1;
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

const max_instance_count = 1000;

const Instance = packed struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    char: u32,
    fill: u96 = 0,
};

const ShaderStorageInfo = struct {
    screen_width: f32,
    screen_height: f32,
    font_width: f32,
    font_height: f32,
};

const ShaderStorageInstance = struct {
    instance_data: [max_instance_count]Instance,
};
