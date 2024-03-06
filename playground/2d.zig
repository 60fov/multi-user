const std = @import("std");

const mu = @import("multi-user");
const platform = mu.platform;
const graphics = mu.graphics;
const chrono = mu.chrono;

const gl = graphics.opengl.gl;
const xy = graphics.xy;

const RndGen = std.rand.DefaultPrng;

const width = 800;
const height = 600;
var sim: ParticleSim = undefined;
var kb: *const platform.input.Keyboard = undefined;
var mouse: *const platform.input.Mouse = undefined;
var iter_count: u64 = 0;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    try platform.init(allocator, "2d", width, height);
    defer platform.deinit();

    try xy.init();
    defer xy.deinit();

    const font_path = "fonts/hack/sdf_32_5";
    const bmp = mu.image.Bmp.create(@embedFile(font_path ++ ".bmp"));
    var sdf_font = graphics.font.Sdf{
        .atlas = try graphics.font.Sdf.parseAtlas(allocator, @embedFile(font_path ++ ".json")),
    };
    sdf_font.load(@constCast(bmp.raw), bmp.width, bmp.height);
    defer sdf_font.atlas.deinit(allocator);
    xy.setFont(sdf_font);

    xy.viewport(800, 600, 1);

    const rects = try std.heap.page_allocator.alloc(ParticleSim.Rect, 10000);
    defer std.heap.page_allocator.free(rects);

    sim = ParticleSim.init(rects);

    var second_timer = chrono.RateLimiter.init(1);
    mouse = platform.input.mouse();
    kb = platform.input.kb();
    var last = std.time.nanoTimestamp();

    while (!platform.shouldQuit()) {
        iter_count += 1;
        platform.poll();

        const now = std.time.nanoTimestamp();
        const ns = now - last;
        last = now;
        sim.update(ns);

        second_timer.call(print_iteration);

        xy.clear();

        xy.text("behind particles", 100, 200, 125, 225, 85);
        sim.draw();
        xy.text("infront of particles", 100, 400, 225, 125, 85);

        xy.flush();

        platform.present();
    }
}

pub fn update(ms: i128) void {
    sim.update(ms);
}

pub fn print_iteration(_: i64) void {
    std.debug.print("{d}\n", .{iter_count});
    iter_count = 0;
}

const ParticleSim = struct {
    const Rect = struct {
        x: f32 = -1,
        y: f32 = -1,
        xvel: f32 = 0,
        yvel: f32 = 0,
        r: u8 = 0,
        g: u8 = 0,
        b: u8 = 0,
    };
    rects: []Rect = undefined,
    rnd: std.rand.Xoshiro256 = undefined,
    gravity: f32,

    pub fn init(rects: []Rect) ParticleSim {
        return ParticleSim{
            .rnd = RndGen.init(57342894123),
            .rects = rects,
            .gravity = 9.8,
        };
    }

    pub fn update(self: *ParticleSim, ns: i128) void {
        const dt = @as(f32, @floatFromInt(ns)) / 1e+9;
        for (self.rects) |*rect| {
            if (rect.x < 0 or rect.x > width or rect.y < 0 or rect.y > height) {
                rect.x = @floatFromInt(mouse.x);
                rect.y = @floatFromInt(height - mouse.y);
                rect.xvel = self.rnd.random().floatNorm(f32) * 100;
                rect.yvel = self.rnd.random().float(f32) * 500;
                rect.r = self.rnd.random().int(u8);
                rect.g = self.rnd.random().int(u8);
                rect.b = self.rnd.random().int(u8);
            }
            rect.yvel -= self.gravity;
            rect.x += rect.xvel * dt;
            rect.y += rect.yvel * dt;
        }
    }

    pub fn draw(self: *ParticleSim) void {
        for (self.rects) |r| {
            xy.rect(@intFromFloat(r.x), @intFromFloat(r.y), 5, 5, r.r, r.g, r.b);
        }
    }
};
