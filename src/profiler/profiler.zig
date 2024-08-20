const std = @import("std");
const assertm = @import("../assertf.zig").assertm;
const timer = @import("timer.zig");

const max_results: u32 = 16;


const Profiler = struct {
    has_timer_started: bool = false,

    total_timer: timer.Timer = .{.cpu_start = 0, .os_start = 0},
    timer: timer.Timer = .{.cpu_start = 0, .os_start = 0},

    results: [max_results]timer.TimerResult = [_]timer.TimerResult{.{.os_elapsed = 0, .cpu_elapsed = 0, .cpu_freq = 0, .name = ""}} ** max_results,
    result_count: u8 = 0,
};

var profiler = Profiler{};

pub fn beginProfiling() void {
    profiler.total_timer.start();
}

pub fn beginTimer() void {

    std.debug.assert(!profiler.has_timer_started);
    profiler.has_timer_started = true;
    profiler.timer.start();
}

pub fn endTimer(comptime name: []const u8) void {

    const result = profiler.timer.end(name);

    std.debug.assert(profiler.has_timer_started);
    std.debug.assert(profiler.result_count < max_results);

    profiler.results[profiler.result_count] = result;
    profiler.result_count += 1;

    profiler.timer.reset();
    profiler.has_timer_started = false;
}

pub fn endProfiling() !void {

    const total = profiler.total_timer.end("Total Time");

    assertm(total.os_elapsed > 0, "You haven't started profiling!");

    const std_out = std.io.getStdOut().writer();

    try std_out.print("Total Time - CPU: {d} ms, OS: {d} seconds\n", .{1000 * @as(f64, @floatFromInt(total.cpu_elapsed)) / @as(f64, @floatFromInt(total.cpu_freq)), 1000 * @as(f64, @floatFromInt(total.os_elapsed)) / @as(f64, @floatFromInt(timer.os_timer_freq))});
    
    for (0..profiler.result_count) |i| {
        const result = &profiler.results[i];
        const cpu_timing: f64 = 1000 * @as(f64,@floatFromInt(result.cpu_elapsed)) / @as(f64,@floatFromInt(result.cpu_freq));
        const portion: f64 = @as(f64,@floatFromInt(result.cpu_elapsed)) / @as(f64,@floatFromInt(total.cpu_elapsed));

        try std_out.print("\t{s} | Elapsed: {d} ms ({d} cycles) ({d}%)\n", .{result.name, cpu_timing, result.cpu_elapsed, 100.0 * portion});
    }

}

