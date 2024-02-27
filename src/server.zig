const std = @import("std");

const softsrv = @import("softsrv");
const net = @import("net.zig");

const game = @import("game.zig");

pub const tick_rate = 120;
pub const conn_max = 256;

// TODO why do these have to be var
pub var ip: std.net.Address = std.net.Address.initIp4([4]u8{ 192, 168, 1, 9 }, 0xbeef);

const Server = @This();

render_view: bool = false,

allocator: std.mem.Allocator,

socket: net.Socket,
connections: []Connection,

state: *game.State,

pub fn update(self: *Server, ms: i64) bool {
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
    game.simulate(self.state, ms);

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
    var tick_limiter = softsrv.chrono.RateLimiter.init(tick_rate);
    // var frame_limiter = softsrv.chrono.RateLimiter.init(Server.RATE);

    var running = true;
    while (running) {
        {
            const steps = tick_limiter.flushAccumulator();
            for (0..steps) |_| {
                running = self.update(tick_limiter.ms);
            }
        }

        // change to comptime debug render
        if (self.render_view) {
            const steps = tick_limiter.flushAccumulator();
            for (0..steps) |_| {
                // Game.render(self.state, self.);
            }
        }
    }
}

const Connection = struct {
    address: std.net.Address,
    last_ping: u64,
    isConnected: bool,
};
