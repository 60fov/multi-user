const std = @import("std");
const gl = @import("gl");

const Shader = @import("shader.zig");
const font = @import("font.zig");

var aspect: f32 = undefined;

const rect_vertices = [_]gl.float{
    0, 1,
    0, 0,
    1, 0,
    1, 1,
};

const rect_indices = [_]gl.ubyte{ 0, 1, 2, 0, 2, 3 };

fn DrawCallQueue(DataType: anytype, max_count: comptime_int) type {
    return struct {
        const Self = @This();
        const buffer_size = max_count * @sizeOf(DataType);

        // TODO see below
        // the only (real) reason to have this is to do some processing before pushing to gpu
        // questions
        // are these too big for the stack (probably)
        // would the heap be too slow (idk, probably not, but def slower than just writing to gpu, maybe...)
        // data: [count]DataType,
        // allocator: std.mem.Allocator,

        vao: gl.uint,
        buffer_id: gl.uint,
        shader_prog: Shader.Program,
        index: usize = 0,

        pub fn init(
            // allocator: std.mem.Allocator,
            vao: gl.uint,
            shader_prog: Shader.Program,
            shader_buffer_index: u32,
        ) Self {
            var id: gl.uint = undefined;
            gl.CreateBuffers(1, @ptrCast(&id));
            gl.NamedBufferStorage(id, Self.buffer_size, null, gl.DYNAMIC_STORAGE_BIT);
            gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, shader_buffer_index, id);

            const dcq = Self{
                .vao = vao,
                .buffer_id = id,
                .shader_prog = shader_prog,
                // .allocator = allocator,
                // .data = try allocator.alloc(DataType, max_count),
            };
            return dcq;
        }

        pub fn push(self: *Self, draw_data: DataType) void {
            if (self.index >= max_count) {
                self.flush();
            }
            // self.data[self.index] = draw_data;
            const size = @sizeOf(DataType);
            const offset = self.index * size;
            gl.NamedBufferSubData(self.buffer_id, @intCast(offset), size, @ptrCast(&draw_data));
            self.index += 1;
        }

        pub fn flush(self: *Self) void {
            gl.BindVertexArray(self.vao);
            self.shader_prog.use();
            // const size = self.index * @sizeOf(DataType);
            // gl.NamedBufferSubData(dcq.buffer_id, 0, size, @ptrCast(&self.data));
            gl.DrawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_BYTE, null, @intCast(self.index));
            self.index = 0;
        }
    };
}

const Instance = struct {
    const Rect = packed struct {
        x: f32,
        y: f32,
        z: f32,
        _padding1: u32 = 0,
        w: f32,
        h: f32,
        _padding2: u64 = 0,
        r: f32,
        g: f32,
        b: f32,
        a: f32 = 1,
    };

    const SdfGlyph = packed struct {
        x: f32,
        y: f32,
        z: f32,
        _padding1: u32 = 0,
        w: f32,
        h: f32,
        _padding2: u64 = 0,
        r: f32,
        g: f32,
        b: f32,
        a: f32,
        char: u32,
        _padding3: u96 = 0,
    };
};

const ShaderStorageInfo = struct {
    screen_width: f32,
    screen_height: f32,
    font_width: f32,
    font_height: f32,
};

var info: ShaderStorageInfo = undefined;

const rect_vs_src = @embedFile("shaders/xy_rect.vert");
const rect_fs_src = @embedFile("shaders/xy_rect.frag");

const sdf_text_vs_src = @embedFile("shaders/xy_sdf_text.vert");
const sdf_text_fs_src = @embedFile("shaders/xy_sdf_text.frag");

var vaos: struct {
    rect: gl.uint,
} = undefined;
const vao_count = @typeInfo(@TypeOf(vaos)).Struct.fields.len;

var buffers: struct {
    vbo: gl.uint,
    ebo: gl.uint,
    sbo_info: gl.uint,
} = undefined;
const buffer_count = @typeInfo(@TypeOf(buffers)).Struct.fields.len;

const DrawCallQueueRect = DrawCallQueue(Instance.Rect, 1000);
const DrawCallQueueSdfText = DrawCallQueue(Instance.SdfGlyph, 1000);

const draw_depth_delta = -1e-8;
var draw_depth: f32 = 1.0;

var dcq_table: struct {
    rects: DrawCallQueueRect,
    sdf_text: DrawCallQueueSdfText,
} = undefined;

var debug_buffer: [4096]u8 = undefined;
var program: struct {
    rect: Shader.Program,
    sdf_text: Shader.Program,
} = undefined;

var current_font: font.Sdf = undefined;

pub fn init() !void {
    gl.Enable(gl.DEBUG_OUTPUT);
    gl.Enable(gl.DEPTH_TEST);

    gl.DebugMessageCallback(debug_callback, null);

    gl.CreateVertexArrays(vao_count, @ptrCast(&vaos));
    gl.CreateBuffers(buffer_count, @ptrCast(&buffers));

    gl.NamedBufferStorage(buffers.vbo, @sizeOf(@TypeOf(rect_vertices)), &rect_vertices, 0);
    gl.NamedBufferStorage(buffers.ebo, @sizeOf(@TypeOf(rect_indices)), &rect_indices, 0);

    gl.NamedBufferStorage(buffers.sbo_info, @sizeOf(ShaderStorageInfo), null, gl.DYNAMIC_STORAGE_BIT);
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, buffers.sbo_info);

    gl.VertexArrayVertexBuffer(vaos.rect, 0, buffers.vbo, 0, 2 * @sizeOf(gl.float));
    gl.VertexArrayElementBuffer(vaos.rect, buffers.ebo);

    // vertex pos
    gl.EnableVertexArrayAttrib(vaos.rect, 0);
    gl.VertexArrayAttribFormat(vaos.rect, 0, 2, gl.FLOAT, gl.FALSE, 0);

    program.rect = Shader.Program.init(.{
        .vertex = Shader.init(.vertex, rect_vs_src),
        .fragment = Shader.init(.fragment, rect_fs_src),
    });

    program.rect.link() catch |err| program.rect.defaultErrorHandler(err);

    program.sdf_text = Shader.Program.init(.{
        .vertex = Shader.init(.vertex, sdf_text_vs_src),
        .fragment = Shader.init(.fragment, sdf_text_fs_src),
    });

    program.sdf_text.link() catch |err| program.sdf_text.defaultErrorHandler(err);

    dcq_table.rects = DrawCallQueueRect.init(vaos.rect, program.rect, 1);
    dcq_table.sdf_text = DrawCallQueueSdfText.init(vaos.rect, program.sdf_text, 2);
}

pub fn clear() void {
    gl.ClearColor(0.1, 0.1, 0.2, 1);
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
}

pub fn setFont(sdf_font: font.Sdf) void {
    current_font = sdf_font;
    info.font_width = @floatFromInt(sdf_font.atlas.glyph_max_width);
    info.font_height = @floatFromInt(sdf_font.atlas.glyph_max_height);
    gl.NamedBufferSubData(buffers.sbo_info, 0, @sizeOf(ShaderStorageInfo), @ptrCast(&info));
    const t_unit = 0;
    gl.BindTextureUnit(t_unit, sdf_font.texture);
}

pub fn deinit() void {
    inline for (@typeInfo(@TypeOf(program)).Struct.fields) |field| {
        @field(program, field.name).delete();
    }
}

pub fn viewport(window_width: i32, window_height: i32, pixel_ratio: f32) void {
    info.screen_width = @floatFromInt(window_width);
    info.screen_height = @floatFromInt(window_height);
    aspect = pixel_ratio;
    gl.Viewport(0, 0, window_width, window_height);
    gl.NamedBufferSubData(buffers.sbo_info, 0, @sizeOf(ShaderStorageInfo), @ptrCast(&info));
}

pub fn rect(x: i32, y: i32, w: i32, h: i32, r: u8, g: u8, b: u8) void {
    const data = Instance.Rect{
        .z = draw_depth,
        .x = @floatFromInt(x),
        .y = @floatFromInt(y),
        .w = @floatFromInt(w),
        .h = @floatFromInt(h),
        .r = @as(f32, @floatFromInt(r)) / 255,
        .g = @as(f32, @floatFromInt(g)) / 255,
        .b = @as(f32, @floatFromInt(b)) / 255,
    };
    dcq_table.rects.push(data);

    draw_depth += draw_depth_delta;
}

pub fn text(str: []const u8, x: i32, y: i32, r: u8, g: u8, b: u8) void {
    var advance: i32 = 0;
    for (str) |c| {
        const glyph = current_font.atlas.rects[c];
        // std.debug.print("[{c}]: depth .{d}\n", .{ c, draw_depth });
        const data = Instance.SdfGlyph{
            .z = draw_depth,
            .x = @as(f32, @floatFromInt(x + advance - glyph.originX)),
            .y = @as(f32, @floatFromInt(y - (glyph.h - glyph.originY))),
            .w = @floatFromInt(glyph.w),
            .h = @floatFromInt(glyph.h),
            .r = @as(f32, @floatFromInt(r)) / 255,
            .g = @as(f32, @floatFromInt(g)) / 255,
            .b = @as(f32, @floatFromInt(b)) / 255,
            .a = 1,
            .char = c,
        };
        advance += glyph.advance;
        dcq_table.sdf_text.push(data);

        draw_depth += draw_depth_delta;
    }
}

pub fn flush() void {
    inline for (@typeInfo(@TypeOf(dcq_table)).Struct.fields) |field| {
        @field(dcq_table, field.name).flush();
    }

    draw_depth = 0.0;
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
