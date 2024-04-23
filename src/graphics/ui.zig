const std = @import("std");

const xy = @import("xy.zig");
const input = @import("../input.zig");
const font = @import("font.zig");

// window
// button
// container
// slider
// list
// drop down
// radio
// check
// toggle
// file select (drag n drop)

pub const State = struct {
    hot_item: i32 = -1,
    active_item: i32 = -1,
    style: struct {
        font: font.Sdf = undefined,
        bg: Color = Color.black,
        fg: Color = Color.white,
        accent: Color = Color.cyan,
    } = .{},
};

const Color = struct {
    pub const black = Color{ .r = 0, .g = 0, .b = 0 };
    pub const white = Color{ .r = 255, .g = 255, .b = 255 };
    pub const red = Color{ .r = 255, .g = 0, .b = 0 };
    pub const green = Color{ .r = 0, .g = 255, .b = 0 };
    pub const blue = Color{ .r = 0, .g = 0, .b = 255 };
    pub const cyan = Color{ .r = 0, .g = 255, .b = 255 };
    pub const magenta = Color{ .r = 255, .g = 0, .b = 255 };
    pub const yellow = Color{ .r = 255, .g = 255, .b = 0 };

    r: u8,
    g: u8,
    b: u8,
};

pub var state: State = .{};

pub fn window(title: []const u8, x: i32, y: i32, w: i32, h: i32) void {
    _ = title;
    const bg = state.style.bg;
    xy.rect(x, y, w, h, bg.r, bg.g, bg.b);
}

pub fn button(text: []const u8, x: i32, y: i32) bool {
    const bg = state.style.bg;
    const fg = state.style.fg;

    const text_w = state.style.font.getTextWidth(text);
    const text_h = state.style.font.getHeight();
    xy.rect(x, y, text_w, text_h, bg.r, bg.g, bg.b);
    xy.text(text, x, y, fg.r, fg.g, fg.b);

    return false;
}
