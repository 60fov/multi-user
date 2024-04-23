const V4f = @Vector(4, f32);

fn m2(a: V4f, b: V4f) V4f {
    return a * b;
}

fn m1(a: [4]f32, b: [4]f32) V4f {
    return @as(V4f, a) * b;
}

pub fn main() void {
    const arr1 = [_]f32{ 1, -2, 0.1, -3 };
    const arr2 = [_]f32{ 2, 13, 5, 6 };

    const vec1: @Vector(4, f32) = arr1;
    const vec2: @Vector(4, f32) = arr2;

    _ = m1(arr1, arr2);
    _ = m2(vec1, vec2);
}
