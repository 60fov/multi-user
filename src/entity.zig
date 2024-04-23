const vec = @import("math/vector.zig");
const Vec2 = vec.Vec2;

const Entity = @This();

tag: Tag,
pos: Vec2,
vel: Vec2,
speed: f32,

pub const Tag = enum {
    empty,
    mob,
    player,
};

pub const SoA = struct {
    pub const max = 16;

    pub const Id = usize;

    tags: [max]Tag = [_]Tag{.empty} ** max,
    velocities: [max]Vec2 = [_]Vec2{.{}} ** max,
    positions: [max]Vec2 = [_]Vec2{.{}} ** max,
    speeds: [max]f32 = [_]f32{0} ** max,

    pub fn set(self: *SoA, id: Id, e: Entity) void {
        self.tags[id] = e.tag;
        self.positions[id] = e.pos;
        self.velocities[id] = e.vel;
        self.speeds[id] = e.speed;
    }

    pub fn get(self: SoA, id: Id) Entity {
        return Entity{
            .tag = self.tags[id],
            .pos = self.positions[id],
            .vel = self.velocities[id],
            .speed = self.speeds[id],
        };
    }
};

pub const Mob = struct {
    tag: Tag = .mob,
    pos: Vec2,
    vel: Vec2,
};
