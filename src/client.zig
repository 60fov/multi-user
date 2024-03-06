const std = @import("std");
const game = @import("game.zig");
const platform = @import("platform.zig");
const chrono = @import("chrono.zig");
const xy = @import("graphics/xy.zig");
const font = @import("graphics/font.zig");
const image = @import("image.zig");

const net = @import("net.zig");
const Server = @import("server.zig");

pub const frame_rate = 300;
pub const tick_rate = Server.tick_rate;

const Client = @This();

const reconnect_time = 1;
const local_host = "172.16.4.7";
const WIDTH = 800;
const HEIGHT = 600;

allocator: std.mem.Allocator,

socket: net.Socket,
connected_to_server: bool = false,
connect_attempt_timer: std.time.Timer,
print_timer: std.time.Timer,

update_count: u32 = 0,
render_count: u32 = 0,

sdf_font: font.Sdf = undefined,

state: *game.State,

pub fn update(self: *Client, ms: i64) bool {
    _ = ms;
    if (!self.connected_to_server) {
        const last_time = self.connect_attempt_timer.read();
        if (last_time >= reconnect_time * 1e+9) {
            self.connect_attempt_timer.reset();
            const packet = net.Packet{ .data = .{ .connect_request = .{} } };
            std.debug.print("attempting to connect to server @ {}...\n", .{Server.ip});
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
                self.state.* = packet.data.state_update.state;
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
            std.debug.print("fps: {d}, tps: {d}\n", .{ self.render_count, self.update_count });
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
    // game.simulate(self.state, ms);

    // render
    // game.render(self.state, &self.framebuffer);

    return true;
}

pub fn init(allocator: std.mem.Allocator) !Client {
    try platform.init(allocator, "multi-user", WIDTH, HEIGHT);
    errdefer platform.deinit();
    std.debug.print("initialized platform\n", .{});

    try xy.init();
    errdefer xy.deinit();
    std.debug.print("initialized 2d renderer\n", .{});

    const font_path = "assets/fonts/hack/sdf_32_5";
    const bmp = image.Bmp.create(@embedFile(font_path ++ ".bmp"));
    var sdf_font = font.Sdf{
        .atlas = try font.Sdf.parseAtlas(allocator, @embedFile(font_path ++ ".json")),
    };
    sdf_font.load(@constCast(bmp.raw), bmp.width, bmp.height);
    errdefer sdf_font.atlas.deinit(allocator);
    std.debug.print("loaded sdf font: {s}\n", .{font_path});

    xy.setFont(sdf_font);
    xy.viewport(800, 600, 1);

    const state = try allocator.create(game.State);
    errdefer allocator.destroy(state);

    state.* = game.initialState();
    std.debug.print("initialized game state: {any}\n", .{state.*});

    var socket = net.Socket{};
    errdefer socket.close();

    try socket.socket(.{});
    try socket.bindAlloc(allocator);
    std.debug.print("client address: {any}\n", .{socket.address.?});

    return Client{
        .allocator = allocator,
        .socket = socket,

        .connect_attempt_timer = try std.time.Timer.start(),
        .print_timer = try std.time.Timer.start(),

        .sdf_font = sdf_font,

        .state = state,
    };
}

pub fn deinit(self: *Client) void {
    self.allocator.destroy(self.state);
    self.sdf_font.atlas.deinit(self.allocator);
    xy.deinit();
    platform.deinit();
    self.socket.close();
}

pub fn run(self: *Client) void {
    var tick_limiter = chrono.RateLimiter.init(Client.tick_rate);
    var frame_limiter = chrono.RateLimiter.init(Client.frame_rate);

    var running = true;
    while (running and !platform.shouldQuit()) {
        // tick
        const update_steps = tick_limiter.flushAccumulator();
        for (0..update_steps) |_| {
            self.update_count += 1;
            running = self.update(tick_limiter.ms);
        }

        // draw
        // TODO change this, doing unecessary stuff in limiter logic
        const shouldDraw = frame_limiter.flushAccumulator() > 0;
        if (shouldDraw) {
            self.render_count += 1;

            xy.clear();
            game.render(self.state);
            xy.flush();

            platform.present();
        }
    }
}

test {
    var client = try Client.init(std.testing.allocator);
    defer client.deinit();
}
