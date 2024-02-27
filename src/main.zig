// server
// [x] send packets to clients
// [x] send 3 object positions
// [x] handle clients dropping in and out

// clients
// [x] send ping to server
// [x] render received objects

const std = @import("std");

const Server = @import("server.zig");
const Client = @import("client.zig");

const Packet = struct {};

const Point = struct {
    x: u32,
    y: u32,
};

const AppMode = enum { server, client };

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const stdout = std.io.getStdOut().writer();
    // try stdout.print("Stuff\n", .{});

    // read cmd line
    var argIter = try std.process.argsWithAllocator(allocator);

    _ = argIter.skip();
    const app_mode_arg = argIter.next() orelse {
        try stdout.print("make sure to set app mode: \nmulti_user_1 server/\n", .{});
        return error.MissingArgs;
    };

    const app_mode_arg_lower = toLower: {
        var buf: [7]u8 = undefined;
        break :toLower std.ascii.lowerString(&buf, app_mode_arg);
    };

    var app_mode: AppMode = undefined;
    if (std.mem.eql(u8, app_mode_arg_lower, "server")) {
        app_mode = AppMode.server;
    } else if (std.mem.eql(u8, app_mode_arg_lower, "client")) {
        app_mode = AppMode.client;
    }

    // TODO implement an interface for server and client
    switch (app_mode) {
        .server => {
            var server = try Server.init(allocator);
            defer server.deinit();

            server.run();
        },
        .client => {
            var client = try Client.init(allocator);
            defer client.deinit();

            client.run();
        },
    }
}
