const std = @import("std");
const builtin = @import("builtin");

const opengl = @import("graphics/opengl.zig");

const Allocator = std.mem.Allocator;
const windows = std.os.windows;

pub const event = @import("event.zig");
pub const input = @import("input.zig");

pub const event_queue: event.EventQueue = undefined;

// TODO seperate platform logic from window (if possible)
var should_quit: bool = false;
var window: Window = undefined;

pub const System = enum {
    windows,
};

var system = switch (builtin.os.tag) {
    .windows => System.windows,
    else => @panic("unhandled os " ++ @tagName(builtin.os.tag)),
};

pub fn init(allocator: Allocator, title: []const u8, w: i32, h: i32) !void {
    // event_queue = event.EventQueue.init(allocator);
    switch (system) {
        .windows => {
            const platform = @import("platform/windows.zig");
            window = .{ .windows = try platform.Window.init(allocator, @ptrCast(title), w, h) };
            const dc = @import("platform/bindings/win32.zig").GetDC(window.windows.handle);
            try platform.initOpenGLContext(dc, .{});
            try opengl.init(platform.getProcAddress);
            window.windows.show();
        },
    }
}

pub fn deinit() void {
    switch (system) {
        .windows => {
            // event_queue.deinit();
            opengl.deinit();
            window.windows.deinit();
        },
    }
}

pub fn quit() void {
    should_quit = true;
}

pub fn shouldQuit() bool {
    return should_quit;
}

pub fn poll() void {
    switch (system) {
        .windows => window.windows.poll(),
    }
}

pub fn present() void {
    switch (system) {
        .windows => {
            window.windows.present();
        },
    }
}

pub const Window = union(System) {
    windows: @import("platform/windows.zig").Window,
};
