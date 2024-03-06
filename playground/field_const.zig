const std = @import("std");

pub fn main() void {
    const A = struct {
        const z = 100;

        b: i32 = 12,
    };
    // i didn't think this would work
    std.debug.print("field {}\n", .{@field(A, "z")});
}
