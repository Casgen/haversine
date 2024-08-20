const std = @import("std");
const timer = @import("profiler/timer.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("OS Timer Frequency: {d}\n", .{timer.os_timer_freq});

    const cpu_start: u64 = timer.rdtsc();

    var elapsed: u64 = 0;
    const start = timer.readOSTime();
    var end: u64 = 0;

    while (elapsed < timer.os_timer_freq) {
        end = timer.readOSTime();
        elapsed = end - start;
    }

    const cpu_end: u64 = timer.rdtsc();
    const cpu_elapsed: u64 = cpu_end - cpu_start;

    var cpu_freq: u64 = 0;

    if (elapsed != 0) {
        cpu_freq = timer.os_timer_freq * cpu_elapsed / elapsed;
    }

    const os_seconds: f64 = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(timer.os_timer_freq));

    try stdout.print("OS Timer: {d} -> {d} = {d} elapsed\n", .{start, end, elapsed});
    try stdout.print("OS Seconds: {d}\n", .{os_seconds});

    try stdout.print("CPU Timer: {d} -> {d} = {d} elapsed\n", .{cpu_start, cpu_end, cpu_elapsed});
    try stdout.print("CPU Freq (guessed): {d} elapsed\n", .{cpu_freq});

    _ = timer.readOSTime();
}
