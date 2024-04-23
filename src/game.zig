const std = @import("std");
const Game = @This();
// const softsrv = @import("softsrv");
// const Framebuffer = softsrv.Framebuffer;
// const BitmapFont = softsrv.BitmapFont;

// const kb = softsrv.input.kb;
// const mouse = softsrv.input.mouse;
const input = @import("input.zig");
const vec = @import("math/vector.zig");

const Vec2 = vec.Vec2;

const Entity = @import("entity.zig");

const kb = input.kb();
const mouse = input.mouse();

const xy = @import("graphics/xy.zig");
const ui = @import("graphics/ui.zig");

var buffer: [4096]u8 = undefined;

const friction: f32 = 0.5;

var player_entity_id: Entity.SoA.Id = 0;

const direction: struct {
    left: Vec2 = Vec2.new(.{ -1, 0 }),
    right: Vec2 = Vec2.new(.{ 1, 0 }),
    up: Vec2 = Vec2.new(.{ 0, 1 }),
    down: Vec2 = Vec2.new(.{ 0, -1 }),
} = .{};

pub const State = struct {
    time: f32 = 0,
    entity: Entity.SoA = .{},
};

pub fn initialState() State {
    var state: State = .{};

    var id: Entity.SoA.Id = 0;

    player_entity_id = id;
    const player = Entity{
        .tag = .player,
        .vel = .{},
        .speed = 1,
        .pos = Vec2.new(.{
            (800 + 50) / 2,
            (600 + 50) / 3 * 2,
        }),
    };
    state.entity.set(id, player);
    // setEntity(&state, id, player);
    id += 1;

    for (0..4) |i| {
        var sfc = std.rand.Sfc64.init(0xbeef);
        var rand = sfc.random();
        const speed = rand.float(f32) * 10 - 5;
        const e = Entity{
            .tag = .mob,
            .pos = Vec2.new(.{
                (@as(f32, @floatFromInt(i)) + 1) * 100,
                100,
            }),
            .vel = Vec2.new(.{
                // 0, 0,
                rand.float(f32) * 2 - 1,
                rand.float(f32) * 2 - 1,
            }),
            .speed = speed,
        };

        state.entity.set(id, e);
        // setEntity(&state, id, e);
        id += 1;
    }

    return state;
}

pub fn simulate(state: *Game.State, dt: u32) void {
    const delta: f32 = @as(f32, @floatFromInt(dt)) / 1e+9 * 1000;
    state.time += delta / 1000;

    {
        var player = state.entity.get(player_entity_id);
        var dir: Vec2 = .{};

        if (kb.key(.KC_S).isDown()) {
            dir = Vec2.add(dir, direction.left);
        }
        if (kb.key(.KC_D).isDown()) {
            dir = Vec2.add(dir, direction.down);
        }
        if (kb.key(.KC_F).isDown()) {
            dir = Vec2.add(dir, direction.right);
        }
        if (kb.key(.KC_E).isDown()) {
            dir = Vec2.add(dir, direction.up);
        }

        dir = Vec2.normalize(dir);
        if (!Vec2.eql(dir, Vec2.zero())) {
            player.vel = Vec2.mulScalar(dir, player.speed);
            state.entity.set(player_entity_id, player);
        }
    }

    for (0..Entity.SoA.max) |_| {}

    // velocity update
    for (0..Entity.SoA.max) |i| {
        const vel = state.entity.velocities[i];
        const mu = Vec2.mulScalar(vel, -friction);
        state.entity.velocities[i] = Vec2.add(vel, mu);
    }

    // position update
    for (0..Entity.SoA.max) |i| {
        // const rot = Vec2.new(.{ std.math.cos(state.time * 10), std.math.sin(state.time * 10) });
        // var vel = Vec2.mulScalar(rot, e.speed);
        const pos = &state.entity.positions[i];
        const vel = Vec2.mulScalar(state.entity.velocities[i], delta);
        pos.* = Vec2.add(pos.*, vel);
    }
}

pub fn interpolate(state: *State, prev_state: *State, next_state: *State, factor: f32) void {
    const lerp = std.math.lerp;

    for (0..Entity.SoA.max) |i| {
        state.entity.tags[i] = next_state.entity.tags[i];

        const vel = &state.entity.velocities[i];
        vel.v[0] = lerp(prev_state.entity.velocities[i].v[0], next_state.entity.velocities[i].v[0], factor);
        vel.v[1] = lerp(prev_state.entity.velocities[i].v[1], next_state.entity.velocities[i].v[1], factor);

        const pos = &state.entity.positions[i];
        pos.v[0] = lerp(prev_state.entity.positions[i].v[0], next_state.entity.positions[i].v[0], factor);
        pos.v[1] = lerp(prev_state.entity.positions[i].v[1], next_state.entity.positions[i].v[1], factor);

        state.entity.speeds[i] = lerp(prev_state.entity.speeds[i], next_state.entity.speeds[i], factor);
    }

    state.time = std.math.lerp(prev_state.time, next_state.time, factor);
}

pub fn render(state: *const Game.State) void {
    xy.clear();

    for (0..Entity.SoA.max) |i| {
        const entity = state.entity.get(i);
        switch (entity.tag) {
            .empty => {},
            .mob => {
                const x: i32 = @intFromFloat(entity.pos.x());
                const y: i32 = @intFromFloat(entity.pos.y());
                // const vx: i32 = @intFromFloat(entity.vel.x());
                // const vy: i32 = @intFromFloat(entity.vel.y());
                xy.rect(x, y, 50, 50, 100, 100, 255);
                // const str = std.fmt.bufPrint(&Game.buffer, "e[{d}] x {d:.1} y {d:.1} vx {d:.1} vy {d:.1}", .{ i, x, y, vx, vy }) catch continue;
                // xy.text(str, 10, 10 + @as(i32, @intCast(i * 32)), 255, 255, 255);
            },
            .player => {
                const x: i32 = @intFromFloat(entity.pos.x());
                const y: i32 = @intFromFloat(entity.pos.y());
                // const vx: i32 = @intFromFloat(entity.vel.x());
                // const vy: i32 = @intFromFloat(entity.vel.y());
                xy.rect(x, y, 25, 25, 255, 255, 255);
                // const str = std.fmt.bufPrint(&Game.buffer, "player x {d:.1} y {d:.1} vx {d:.1} vy {d:.1}", .{ x, y, vx, vy }) catch continue;
                // xy.text(str, 10, @as(i32, @intFromFloat(xy.screen_height() - 64)), 255, 255, 255);
            },
        }

        // debug draw
        {
            time: {
                const str = std.fmt.bufPrint(&Game.buffer, "time: {d:.1}", .{state.time}) catch break :time;
                xy.text(str, 10, @intFromFloat(xy.screen_height() - 32), 255, 255, 255);
            }

            _ = ui.button("click me!", 100, 100);
        }
    }

    xy.flush();
}
