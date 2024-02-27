const std = @import("std");
const game = @import("../game.zig");

const Packet = @This();

data: Data,

pub const Tag = enum {
    never,

    ping, // client and server send

    connect_request, // client send
    connect_response, // server send

    state_update, // sever send
};

pub const Data = union(Tag) {
    never: void,
    ping: Ping,
    connect_request: ConnectRequest,
    connect_response: ConnectResponse,

    state_update: StateUpdate,
};

pub const Ping = struct {
    pub fn write(self: *const Ping, buffer: *Buffer) void {
        _ = self;
        buffer.write(u8, @intFromEnum(Tag.ping));
    }
};

pub const StateUpdate = struct {
    state: game.State,

    pub fn write(self: *const StateUpdate, buffer: *Buffer) void {
        buffer.write(u8, @intFromEnum(Tag.state_update));
        for (self.state.entities) |entity| {
            buffer.write(f32, entity.pos.x);
            buffer.write(f32, entity.pos.y);
            buffer.write(f32, entity.vel.x);
            buffer.write(f32, entity.vel.y);
        }
        buffer.write(f32, self.state.player.pos.x);
        buffer.write(f32, self.state.player.pos.y);
        buffer.write(f32, self.state.player.vel.x);
        buffer.write(f32, self.state.player.vel.y);
    }

    pub fn read(self: *StateUpdate, buffer: *Buffer) void {
        for (&self.state.entities) |*entity| {
            entity.pos.x = buffer.read(f32);
            entity.pos.y = buffer.read(f32);
            entity.vel.x = buffer.read(f32);
            entity.vel.y = buffer.read(f32);
        }
        self.state.player.pos.x = buffer.read(f32);
        self.state.player.pos.y = buffer.read(f32);
        self.state.player.vel.x = buffer.read(f32);
        self.state.player.vel.y = buffer.read(f32);
    }
};

pub const ConnectRequest = struct {
    pub fn write(self: *const ConnectRequest, buffer: *Buffer) void {
        _ = self;
        buffer.write(u8, @intFromEnum(Tag.connect_request));
    }
};

pub const ConnectResponse = struct {
    id: u8,

    pub fn write(self: *const ConnectResponse, buffer: *Buffer) void {
        buffer.write(u8, @intFromEnum(Tag.connect_response));
        buffer.write(u8, self.id);
    }
    pub fn read(self: *ConnectResponse, buffer: *Buffer) void {
        self.id = buffer.read(u8);
    }
};

pub const Buffer = struct {
    data: []u8,
    index: usize,

    pub fn write(self: *Buffer, comptime T: type, value: T) void {
        switch (T) {
            u8, u16, u32, i8, i16, i32 => {
                const size = @sizeOf(T);
                std.debug.assert(self.index + size <= self.data.len);

                const dest = self.data[self.index..][0..size];
                std.mem.writeInt(T, dest, value, .little);
                self.index += size;
            },
            f16, f32 => {
                const size = @sizeOf(T);
                const IntType = std.meta.Int(.unsigned, @bitSizeOf(T));
                std.debug.assert(self.index + size <= self.data.len);

                const dest = self.data[self.index..][0..size];
                std.mem.writeInt(IntType, dest, @as(IntType, @bitCast(value)), .little);
                self.index += size;
            },
            else => @compileError("packet buffer write, unhandled type " ++ @typeName(T)),
        }
    }

    pub fn read(self: *Buffer, comptime T: type) T {
        switch (T) {
            u8, u16, u32, i8, i16, i32 => {
                const size = @sizeOf(T);
                std.debug.assert(self.index + size <= self.data.len);

                const src = self.data[self.index..][0..size];
                self.index += size;
                return std.mem.readInt(T, src, .little);
            },
            f16, f32 => {
                const size = @sizeOf(T);
                const IntType = std.meta.Int(.unsigned, @bitSizeOf(T));
                std.debug.assert(self.index + size < self.data.len);

                const src = self.data[self.index..][0..size];
                self.index += size;
                // TODO consider making readFloat function
                return @bitCast(std.mem.readInt(IntType, src, .little));
            },
            else => @compileError("packet buffer read, unhandled type " ++ @typeName(T)),
        }
    }
};

pub fn read(self: *Packet, buffer: []u8) !void {
    var buff = Buffer{
        .data = buffer,
        .index = 0,
    };
    const tag: Tag = @enumFromInt(buff.read(u8));

    switch (tag) {
        .ping => {
            self.* = .{ .data = .{ .ping = .{} } };
        },
        .connect_request => {
            self.* = .{ .data = .{ .connect_request = .{} } };
        },
        .connect_response => {
            self.* = Packet{ .data = .{ .connect_response = undefined } };
            self.data.connect_response.read(&buff);
        },
        .state_update => {
            self.* = Packet{ .data = .{ .state_update = undefined } };
            self.data.state_update.read(&buff);
        },
        else => return error.PacketReadUnhandledTag,
    }
}

pub fn write(self: *const Packet, buffer: []u8) !void {
    var buff = Buffer{
        .data = buffer,
        .index = 0,
    };

    switch (self.data) {
        .ping => {
            self.data.ping.write(&buff);
        },
        .connect_request => {
            self.data.connect_request.write(&buff);
        },
        .connect_response => {
            self.data.connect_response.write(&buff);
        },
        .state_update => {
            self.data.state_update.write(&buff);
        },
        else => return error.PacketWriteUnhandledTag,
    }
}
