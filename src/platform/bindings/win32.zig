const std = @import("std");
const windows = std.os.windows;

pub usingnamespace @import("win32/windef.zig");
pub usingnamespace @import("win32/wingdi.zig");
pub usingnamespace @import("win32/winuser.zig");
pub usingnamespace @import("win32/libloaderapi.zig");
pub usingnamespace @import("win32/errhandlingapi.zig");
pub usingnamespace @import("win32/winbase.zig");
pub usingnamespace @import("win32/wgl.zig");
