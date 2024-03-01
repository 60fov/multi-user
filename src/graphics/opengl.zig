const std = @import("std");
pub const gl = @import("gl");

var procs: gl.ProcTable = undefined;

pub fn init(getProcAddress: anytype) !void {
    if (!procs.init(getProcAddress)) {
        return error.failedToLoadOpenglFunctions;
    }
    gl.makeProcTableCurrent(&procs);
}

pub fn deinit() void {
    gl.makeProcTableCurrent(null);
}
