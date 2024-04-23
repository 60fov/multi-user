const std = @import("std");

// TODO swizzle
// TODO @Vector support
// TODO perf analysis / inspect asm (inline?)

pub fn Vec(dimensions: comptime_int, T: type) type {
    return struct {
        const Self = @This();
        pub const Array = [dim]T;
        pub const Scalar = T;

        pub const dim = dimensions;
        pub const mem_size = @sizeOf(Array);

        v: Array = [_]T{0} ** dim,

        pub fn new(values: Array) Self {
            return Self{
                .v = values,
            };
        }

        pub fn splat(value: Scalar) Self {
            var v: Self = .{};
            for (0..dim) |i| {
                v.v[i] = value;
            }
            return v;
        }

        pub fn zero() Self {
            return Self{
                .v = [_]T{0} ** dim,
            };
        }

        pub fn x(v: Self) T {
            comptime if (dim < 1) @compileError("too few dimensions, no x");
            return v.v[0];
        }

        pub fn y(v: Self) T {
            comptime if (dim < 2) @compileError("too few dimensions, no y");
            return v.v[1];
        }

        pub fn z(v: Self) T {
            comptime if (dim < 3) @compileError("too few dimensions, no z");
            return v.v[2];
        }

        pub fn w(v: Self) T {
            comptime if (dim < 4) @compileError("too few dimensions, no w");
            return v.v[3];
        }

        pub fn add(a: Self, b: Self) Self {
            var v: Array = undefined;
            for (0..dim) |i| {
                v[i] = a.v[i] + b.v[i];
            }
            return Self{ .v = v };
        }

        pub fn sub(a: Self, b: Self) Self {
            var v: Array = undefined;
            for (0..dim) |i| {
                v[i] = a.v[i] - b.v[i];
            }
            return Self{ .v = v };
        }

        pub fn mul(a: Self, b: Self) Self {
            var v: Array = undefined;
            for (0..dim) |i| {
                v[i] = a.v[i] * b.v[i];
            }
            return Self{ .v = v };
        }

        pub fn div(a: Self, b: Self) Self {
            var v: Array = undefined;
            for (0..dim) |i| {
                v[i] = a.v[i] / b.v[i];
            }
            return Self{ .v = v };
        }

        pub fn addScalar(a: Self, b: Scalar) Self {
            var v: Array = undefined;
            for (0..dim) |i| {
                v[i] = a.v[i] + b;
            }
            return Self{ .v = v };
        }

        pub fn subScalar(a: Self, b: Scalar) Self {
            var v: Array = undefined;
            for (0..dim) |i| {
                v[i] = a.v[i] - b;
            }
            return Self{ .v = v };
        }

        pub fn mulScalar(a: Self, b: Scalar) Self {
            var v: Array = undefined;
            for (0..dim) |i| {
                v[i] = a.v[i] * b;
            }
            return Self{ .v = v };
        }

        /// doesn't check for zero
        pub fn divScalar(a: Self, b: Scalar) Self {
            var v: Array = undefined;
            for (0..dim) |i| {
                v[i] = a.v[i] / b;
            }
            return Self{ .v = v };
        }

        pub fn dot(a: Self, b: Self) T {
            var v: T = 0;
            for (0..dim) |i| {
                v += a.v[i] * b.v[i];
            }
            return v;
        }

        pub inline fn length2(a: Self) T {
            return dot(a, a);
        }

        pub inline fn length(a: Self) T {
            return std.math.sqrt(dot(a, a));
        }

        pub inline fn normalize(a: Self) Self {
            const l2 = length2(a);
            if (l2 == 0) return a;
            return divScalar(a, std.math.sqrt(l2));
        }

        pub inline fn eql(a: Self, b: Self) bool {
            return std.mem.eql(Scalar, &a.v, &b.v);
        }
    };
}

pub const Vec2 = Vec(2, f32);
pub const Vec3 = Vec(3, f32);
pub const Vec4 = Vec(4, f32);

test {
    const testing = std.testing;
    try testing.expectEqual(Vec2.dim, 2);
    try testing.expectEqual(Vec2.Scalar, f32);
    const v1 = Vec2.new(.{ 1, 2 });
    const v2 = Vec2.new(.{ 2, -1 });
    const v0: Vec2 = .{};
    try testing.expectEqual(v0, Vec2.new(.{ 0, 0 }));

    // compiler errors
    // _ = v2.z();
    // _ = v2.w();

    try testing.expectEqual(Vec2.add(v1, v2), Vec2.new(.{ 3, 1 }));
    try testing.expectEqual(Vec2.sub(v1, v2), Vec2.new(.{ -1, 3 }));
    try testing.expectEqual(Vec2.mul(v1, v2), Vec2.new(.{ 2, -2 }));
    try testing.expectEqual(Vec2.div(v1, v2), Vec2.new(.{ 0.5, -2 }));
    try testing.expectEqual(Vec2.dot(v1, v2), 0);
    try testing.expectEqual(Vec2.dot(v1, v1), 1.0 * 1.0 + 2.0 * 2.0);
    try testing.expectEqual(Vec2.length(v1), std.math.sqrt(1.0 * 1.0 + 2.0 * 2.0));
    const len = std.math.sqrt(1.0 * 1.0 + 2.0 * 2.0);
    try testing.expectEqual(Vec2.normalize(v1), Vec2.divScalar(v1, len));

    const v3 = Vec(4, f32).new(.{ 5, 4, 3, 2 });

    try testing.expectEqual(v3.x(), 5);
    try testing.expectEqual(v3.y(), 4);
    try testing.expectEqual(v3.z(), 3);
    try testing.expectEqual(v3.w(), 2);
}
