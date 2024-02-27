const std = @import("std");
const Game = @This();
const softsrv = @import("softsrv");
const Framebuffer = softsrv.Framebuffer;
const BitmapFont = softsrv.BitmapFont;

const kb = softsrv.input.kb;
const mouse = softsrv.input.mouse;

pub const Vec2 = struct {
    x: f32 = 0,
    y: f32 = 0,
};

pub const Entity = struct {
    pos: Vec2 = .{},
    vel: Vec2 = .{},
    speed: f32 = 0.5,
};

pub const State = struct {
    entities: [3]Entity = [_]Entity{ .{}, .{}, .{} },
    player: Entity = .{},
    time: f32 = 0,
};

pub fn initialState() State {
    var state: State = .{};
    for (&state.entities, 0..) |*e, i| {
        e.pos.x = (@as(f32, @floatFromInt(i)) + 1) * 100;
        e.pos.y = 100;
    }

    state.player.pos.x = (800 + 50) / 2;
    state.player.pos.y = (600 + 50) / 3 * 2;

    return state;
}

pub fn simulate(state: *Game.State, ms: i64) void {
    const delta = @as(f32, @floatFromInt(ms)) / 1000;
    state.time += delta;

    {
        var dx: f32 = 0;
        var dy: f32 = 0;

        if (kb().key(.KC_S).isDown()) {
            dx += -1;
        }
        if (kb().key(.KC_C).isDown()) {
            dy += 1;
        }
        if (kb().key(.KC_F).isDown()) {
            dx += 1;
        }
        if (kb().key(.KC_E).isDown()) {
            dy += -1;
        }

        state.player.vel.x = dx * state.player.speed;
        state.player.vel.y = dy * state.player.speed;

        state.player.pos.x += state.player.vel.x * delta;
        state.player.pos.y += state.player.vel.y * delta;
        if (state.player.pos.x < 0) state.player.pos.x = 0;
        if (state.player.pos.y < 0) state.player.pos.y = 0;
    }

    for (&state.entities, 0..) |*e, i| {
        const offset: f32 = @floatFromInt(i);
        const dx = @cos((state.time + offset) / 50);
        const dy = @sin((state.time + offset) / 50);
        e.vel.x = @floatCast(dx);
        e.vel.y = @floatCast(dy);
        e.vel.x *= e.speed;
        e.vel.y *= e.speed;
        e.pos.x += e.vel.x * delta;
        e.pos.y += e.vel.y * delta;
    }
}

pub fn render(state: *const Game.State, fb: *Framebuffer) void {
    fb.clear();

    const p = state.player;
    softsrv.draw.rect(fb, @intFromFloat(p.pos.x), @intFromFloat(p.pos.y), 50, 50, 100, 100, 255);

    const font = try softsrv.getDefaultFont();
    const buffer = try softsrv.getDebugBuffer();
    for (state.entities, 0..) |e, i| {
        softsrv.draw.rect(fb, @intFromFloat(e.pos.x), @intFromFloat(e.pos.y), 50, 50, 255, 100, 100);
        const str = std.fmt.bufPrint(buffer, "e[{d}] x {d:.1} y {d:.1} vx {d:.1} vy {d:.1}", .{ i, e.pos.x, e.pos.y, e.vel.x, e.vel.y }) catch continue;
        softsrv.draw.text(fb, str, font, 10, 10 + @as(i32, @intCast(i * 10)));
    }

    softsrv.platform.present(fb);
}
