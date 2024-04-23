const std = @import("std");

const game = @import("game.zig");
const platform = @import("platform.zig");
const chrono = @import("chrono.zig");
const xy = @import("graphics/xy.zig");
const font = @import("graphics/font.zig");
const image = @import("image.zig");
const asset = @import("asset.zig");
const net = @import("net.zig");
const shader = @import("graphics/shader.zig");
const global = @import("global.zig");
const ui = @import("graphics/ui.zig");

const Server = @import("server.zig");

pub const frame_rate = 300;
pub const tick_rate = Server.tick_rate;

const Client = @This();

const reconnect_time = 1;
const local_host = "172.16.4.7";
const WIDTH = 800;
const HEIGHT = 600;

allocator: std.mem.Allocator,

running: bool = true,

socket: net.Socket,
connected_to_server: bool = false,
connect_attempt_timer: std.time.Timer,
print_timer: std.time.Timer,

update_count: u32 = 0,
render_count: u32 = 0,

state_prev: *game.State,
state_next: *game.State,

pub fn update(self: *Client, dt: u32) bool {
    if (!self.connected_to_server) {
        const last_time = self.connect_attempt_timer.read();
        if (last_time >= reconnect_time * 1e+9) {
            self.connect_attempt_timer.reset();
            const packet = net.Packet{ .data = .{ .connect_request = .{} } };
            // std.debug.print("attempting to connect to server @ {}...\n", .{Server.ip});
            self.socket.sendPacket(&packet, Server.ip) catch |err| {
                std.debug.print("failed to send connect packet, error {s}\n", .{@errorName(err)});
            };
        }
    }

    // recv server updates
    var sender_ip: std.net.Address = undefined;
    while (self.socket.recvPacket(&sender_ip)) |packet| {
        if (!sender_ip.eql(Server.ip)) continue;

        switch (packet.data) {
            .ping => {
                std.debug.print("ping!\n", .{});
            },
            .connect_response => {
                std.debug.print("connected to server, id: {d}\n", .{packet.data.connect_response.id});
                self.connected_to_server = true;
            },
            .state_update => {
                self.state_next.* = packet.data.state_update.state;
            },
            else => {
                std.debug.print("unhandled packet type: {s}\n", .{@tagName(packet.data)});
            },
        }
    } else |err| switch (err) {
        error.WouldBlock => {},
        error.ConnectionResetByPeer => self.connected_to_server = false,
        else => {
            std.debug.print("unhandled error: {s}\n", .{@errorName(err)});
            return false;
        },
    }

    {
        const elapsed = self.print_timer.read();
        if (elapsed > 1 * 1e+9) {
            self.print_timer.reset();
            // std.debug.print("fps: {d}, tps: {d}\n", .{ self.render_count, self.update_count });
            self.render_count = 0;
            self.update_count = 0;
        }
    }

    // process inputs
    platform.poll();
    // input.update();

    // TODO
    // send client input to server
    // interp rendition

    // update game state
    self.state_prev.* = self.state_next.*;
    game.simulate(self.state_next, dt);

    return true;
}

pub fn init(allocator: std.mem.Allocator) !Client {
    try platform.init(allocator, "multi-user", WIDTH, HEIGHT);
    errdefer platform.deinit();
    std.debug.print("initialized platform\n", .{});

    shader.init(allocator);
    errdefer shader.deinit();

    font.init(allocator);
    errdefer font.deinit();

    const font_path = "fonts/hack/sdf_32_5";
    var sdf_font = try font.Sdf.init(font_path);
    errdefer sdf_font.atlas.deinit(allocator);
    font.manager.add("hack", sdf_font);
    std.debug.print("loaded sdf font: {s}\n", .{font_path});

    try xy.init();
    errdefer xy.deinit();
    std.debug.print("initialized 2d renderer\n", .{});

    xy.setFont(sdf_font);
    xy.viewport(800, 600, 1);

    const state_prev_ptr = try allocator.create(game.State);
    errdefer allocator.destroy(state_prev_ptr);
    const state_next_ptr = try allocator.create(game.State);
    errdefer allocator.destroy(state_next_ptr);

    state_prev_ptr.* = game.initialState();
    state_next_ptr.* = state_prev_ptr.*;

    std.debug.print("initialized game state\n", .{});

    var socket = net.Socket{};
    errdefer socket.close();

    try socket.socket(.{});
    try socket.bindAlloc(allocator);
    std.debug.print("client address: {any}\n", .{socket.address.?});

    ui.state = .{ .style = .{ .font = xy.getDefaultFont() } };

    return Client{
        .allocator = allocator,
        .socket = socket,

        .connect_attempt_timer = try std.time.Timer.start(),
        .print_timer = try std.time.Timer.start(),

        .state_prev = state_prev_ptr,
        .state_next = state_next_ptr,
    };
}

pub fn deinit(self: *Client) void {
    shader.deinit();
    self.allocator.destroy(self.state_next);
    self.allocator.destroy(self.state_prev);
    xy.deinit();
    platform.deinit();
    self.socket.close();
}

pub fn run(self: *Client) void {
    // 16, 20, 25, 32, 40, 50, 64, 80, 100, 125, 128, 160, 200, 250, 256
    // possible tickrates (factors of 1e+n resulting in rational values)
    // this is important since nanoTimestamp returns an integer
    const dt: u32 = @divExact(1e+9, 128);

    var last = std.time.nanoTimestamp();
    var frame_time_accumulator: u32 = 0;

    while (self.running) {
        if (platform.shouldQuit()) break;

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
            self.update_count += 1;
            shader.manager.watch();
            _ = self.update(dt);
            frame_time_accumulator -= dt;
        }

        const interp_factor: f32 = @as(f32, @floatFromInt(frame_time_accumulator)) / @as(f32, @floatFromInt(dt));
        var state_interp: game.State = .{};
        game.interpolate(&state_interp, self.state_prev, self.state_next, interp_factor);

        self.render_count += 1;
        game.render(&state_interp);
        platform.present();
    }
}

test {
    var client = try Client.init(std.testing.allocator);
    defer client.deinit();
}
