const std = @import("std");

pub fn assertf(ok: bool, comptime msg: []const u8, args: anytype) void {
    if (!ok) {
        std.debug.print(msg, args);
        std.debug.assert(ok);
    }
}
pub fn assertm(ok: bool, comptime msg: []const u8) void {
    if (!ok) {
        _ = std.io.getStdErr().write(msg) catch |err| {
            std.debug.print("Assert has failed at writing out an error! {s}",.{@errorName(err)});
        };
        std.debug.assert(ok);
    }
}

