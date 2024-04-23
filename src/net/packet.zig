const std = @import("std");
const game = @import("../game.zig");
const vec = @import("../math/vector.zig");

const Entity = @import("../entity.zig");
const Vec2 = vec.Vec2;
const Vec3 = vec.Vec3;

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

        buffer.write(f32, self.state.time);

        for (0..Entity.SoA.max) |i| {
            const tag = self.state.entity.tags[i];
            buffer.write(u8, @as(u8, @intFromEnum(tag)));
        }

        for (0..Entity.SoA.max) |i| {
            const pos = self.state.entity.positions[i];
            buffer.write(Vec2, pos);
        }

        for (0..Entity.SoA.max) |i| {
            const vel = self.state.entity.velocities[i];
            buffer.write(Vec2, vel);
        }

        for (0..Entity.SoA.max) |i| {
            const speed = self.state.entity.speeds[i];
            buffer.write(f32, speed);
        }
    }

    pub fn read(self: *StateUpdate, buffer: *Buffer) void {
        self.state.time = buffer.read(f32);

        for (0..Entity.SoA.max) |i| {
            self.state.entity.tags[i] = @enumFromInt(buffer.read(u8));
        }

        for (0..Entity.SoA.max) |i| {
            self.state.entity.positions[i] = buffer.read(Vec2);
        }

        for (0..Entity.SoA.max) |i| {
            self.state.entity.velocities[i] = buffer.read(Vec2);
        }

        for (0..Entity.SoA.max) |i| {
            self.state.entity.speeds[i] = buffer.read(f32);
        }
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

    inline fn writeInt(self: *Buffer, comptime T: type, value: T) void {
        const size = @sizeOf(T);
        std.debug.assert(self.index + size <= self.data.len);

        const dest = self.data[self.index..][0..size];
        std.mem.writeInt(T, dest, value, .little);
        self.index += size;
    }

    inline fn writeFloat(self: *Buffer, comptime T: type, value: T) void {
        const size = @sizeOf(T);
        const IntType = std.meta.Int(.unsigned, @bitSizeOf(T));
        std.debug.assert(self.index + size <= self.data.len);

        const dest = self.data[self.index..][0..size];
        std.mem.writeInt(IntType, dest, @as(IntType, @bitCast(value)), .little);
        self.index += size;
    }

    pub fn write(self: *Buffer, comptime T: type, value: T) void {
        switch (T) {
            u8, u16, u32, i8, i16, i32 => writeInt(self, T, value),
            f16, f32 => writeFloat(self, T, value),
            Vec2, Vec3 => inline for (value.v) |v| writeFloat(self, T.Scalar, v),
            else => @compileError("packet buffer write, unhandled type " ++ @typeName(T)),
        }
    }

    inline fn readInt(self: *Buffer, comptime T: type) T {
        const size = @sizeOf(T);
        std.debug.assert(self.index + size <= self.data.len);

        const src = self.data[self.index..][0..size];
        self.index += size;
        return std.mem.readInt(T, src, .little);
    }

    inline fn readFloat(self: *Buffer, comptime T: type) T {
        const size = @sizeOf(T);
        const IntType = std.meta.Int(.unsigned, @bitSizeOf(T));
        std.debug.assert(self.index + size < self.data.len);

        const src = self.data[self.index..][0..size];
        self.index += size;
        return @bitCast(std.mem.readInt(IntType, src, .little));
    }

    pub fn read(self: *Buffer, comptime T: type) T {
        return switch (T) {
            u8, u16, u32, i8, i16, i32 => readInt(self, T),
            f16, f32 => readFloat(self, T),
            Vec2, Vec3 => {
                var v: Vec2 = undefined;
                inline for (0..T.dim) |i| {
                    v.v[i] = readFloat(self, T.Scalar);
                }
                return v;
            },
            else => @compileError("packet buffer read, unhandled type " ++ @typeName(T)),
        };
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
