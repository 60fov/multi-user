const std = @import("std");
const windows = std.os.windows;
const WINAPI = windows.WINAPI;

/// https://learn.microsoft.com/en-us/windows/win32/api/errhandlingapi/nf-errhandlingapi-getlasterror
pub extern "kernel32" fn GetLastError() callconv(WINAPI) windows.DWORD;

pub const FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100;
pub const FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000;
pub const FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200;

// TODO move to winbase.zig
/// https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-formatmessagea
pub extern "kernel32" fn FormatMessageA(
    dwFlags: windows.DWORD,
    lpSource: ?windows.LPCVOID,
    dwMessageId: windows.DWORD,
    dwLanguageId: windows.DWORD,
    lpBuffer: windows.LPSTR,
    nSize: windows.DWORD,
    Arguments: ?*c_char,
) callconv(WINAPI) windows.DWORD;

pub fn MAKELANGID(primaryLangId: windows.WORD, subLangId: windows.WORD) windows.WORD {
    return (subLangId << 10) | primaryLangId;
}
