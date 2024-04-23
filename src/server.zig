const std = @import("std");

// const softsrv = @import("softsrv");
const chrono = @import("chrono.zig");
const net = @import("net.zig");

const game = @import("game.zig");

pub const tick_rate = 20;
pub const conn_max = 256;

// TODO why do these have to be var

pub var ip: std.net.Address = std.net.Address.initIp4([4]u8{ 172, 16, 4, 7 }, 0xbeef);

const Server = @This();

running: bool = true,
render_view: bool = false,

allocator: std.mem.Allocator,

socket: net.Socket,
connections: []Connection,

state: *game.State,

pub fn update(self: *Server, dt: u32) bool {
    // ingest incomming packets
    var sender_ip: std.net.Address = undefined;
    while (self.socket.recvPacket(&sender_ip)) |packet| {
        switch (packet.data) {
            .ping => {
                std.debug.print("[{}] ping!\n", .{sender_ip});
                const response = net.Packet{ .data = .{ .ping = .{} } };
                self.socket.sendPacket(&response, sender_ip) catch |err| {
                    std.debug.print("failed to send packet, error {s}\n", .{@errorName(err)});
                    continue;
                };
            },
            .connect_request => blk: {
                for (self.connections, 0..) |*conn, conn_id| {
                    if (conn.isConnected) {
                        if (conn.address.eql(sender_ip)) break; // client already connected.
                        continue; // slot taken
                    }
                    std.debug.print("new connection, addr: {}, conn_id: {d}\n", .{ sender_ip, conn_id });
                    conn.isConnected = true;
                    conn.address = sender_ip;
                    // conn.last_ping = std.time.timestamp();
                    const response = net.Packet{ .data = .{ .connect_response = .{ .id = @intCast(conn_id) } } };
                    self.socket.sendPacket(&response, sender_ip) catch |err| {
                        std.debug.print("failed to send packet, error {s}\n", .{@errorName(err)});
                        break :blk;
                    };
                    // TODO notify all other connections new player connected (not needed i think)
                    break :blk;
                }
                std.debug.print("failed to add to connections\n", .{});
            },
            else => {
                std.debug.print("unhandled packet type: {s}\n", .{@tagName(packet.data)});
            },
        }
    } else |err| switch (err) {
        error.WouldBlock => {},
        error.ConnectionResetByPeer => {},
        else => {
            std.debug.print("[unhandled error] recv'ing packet: {s}\n", .{@errorName(err)});
            return false;
        },
    }

    // update game state
    game.simulate(self.state, dt);

    // send new game state
    {
        for (self.connections) |conn| {
            if (conn.isConnected) {
                const packet: net.Packet = .{ .data = .{ .state_update = .{ .state = self.state.* } } };
                self.socket.sendPacket(&packet, conn.address) catch |err| {
                    std.debug.print("failed to send packet to {}, error {s}\n", .{ conn.address, @errorName(err) });
                };
            }
        }
    }

    return true;
}

pub fn init(allocator: std.mem.Allocator) !Server {
    const state = try allocator.create(game.State);
    state.* = game.initialState();

    std.debug.print("initialized game state\n", .{});

    var socket = net.Socket{
        .address = ip,
    };

    // const addr_list = try std.net.getAddressList(allocator, "", 0xbeef);
    // defer addr_list.deinit();
    // for (addr_list.addrs) |addr| {
    //     std.debug.print("addr: {}\n", .{addr});
    // }

    try socket.socket(.{});
    try socket.bind();
    std.debug.print("server address {}\n", .{socket.address.?});

    return Server{
        .allocator = allocator,
        .socket = socket,
        .connections = try allocator.alloc(Connection, conn_max),
        .state = state,
    };
}

pub fn deinit(self: *Server) void {
    self.allocator.free(self.connections);
    self.socket.close();
}

pub fn send(self: *Server, conn: Connection, buf: []const u8) !usize {
    return self.socket.sendto(conn.address, buf);
}

pub fn isAddressConnected(self: *Server, address: std.net.Address) bool {
    for (self.connections.items) |connection| {
        if (connection.address.eql(address)) {
            return true;
        }
    }
    return false;
}

pub fn run(self: *Server) void {
    // 16, 20, 25, 32, 40, 50, 64, 80, 100, 125, 128, 160, 200, 250, 256
    // possible tickrates (factors of 1e+n resulting in rational values)
    // this is important since nanoTimestamp returns an integer
    const dt: u32 = @divExact(1e+9, 128);

    var last = std.time.nanoTimestamp();
    var frame_time_accumulator: u32 = 0;

    while (self.running) {
        // if (platform.shouldQuit()) break;

        const now = std.time.nanoTimestamp();
        // what happens if delta (now-last) > max(u32)?
        var frame_time: u32 = @intCast(now - last);

        // crash if falling behind (can't do, need separate window thread)
        // std.debug.assert(frame_time <= dt);

        if (frame_time > dt) {
            const over_time = frame_time - dt;
            std.debug.print("fell behind. lost {d}ms\n", .{over_time / (1000 * 1000)});
            frame_time = dt;
        }

        last = now;

        frame_time_accumulator += frame_time;

        while (frame_time_accumulator > dt) {
            // self.update_count += 1;
            _ = self.update(dt);
            frame_time_accumulator -= dt;
        }

        // if (self.render_view) {
        //     const interp_factor: f32 = @as(f32, @floatFromInt(frame_time_accumulator)) / @as(f32, @floatFromInt(dt));
        //     const state_interp: game.State = game.interpolate(self.state_prev, self.state_next, interp_factor);

        //     self.render_count += 1;
        //     game.render(&state_interp);
        //     platform.present();
        // }
    }
}

const Connection = struct {
    address: std.net.Address,
    last_ping: u64,
    isConnected: bool,
};
