const std = @import("std");
const windows = std.os.windows;
const WINAPI = windows.WINAPI;

pub extern "kernel32" fn MulDiv(
    nNumber: windows.INT,
    nNumerator: windows.INT,
    nDenominator: windows.INT,
) callconv(WINAPI) windows.INT;
