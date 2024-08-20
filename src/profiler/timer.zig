const std = @import("std");

pub const os_timer_freq: u64 = 1000000;

pub const TimerResult = struct {
    os_elapsed: u64,
    cpu_elapsed: u64,
    cpu_freq: u64,
    name: []const u8,

    pub fn print(self: *const TimerResult) !void {
        try std.io.getStdOut().writer().print("Cpu Freq: {d} | OS Elapsed: {d} seconds ({d} ticks) | CPU Elapsed {d}\n",
            .{
                self.cpu_freq,
                @as(f64, @floatFromInt(self.os_elapsed)) / @as(f64, @floatFromInt(os_timer_freq)),
                self.os_elapsed,
                self.cpu_elapsed
            }
        );
    }

    pub fn printDesc(self: *const TimerResult, comptime desc: []const u8) !void {
        try std.io.getStdOut().writer().print("{s}Cpu Freq: {d} | OS Elapsed: {d} seconds ({d} ticks) | CPU Elapsed {d}\n", .{ desc, self.cpu_freq, @as(f64, @floatFromInt(self.os_elapsed)) / @as(f64, @floatFromInt(os_timer_freq)), self.os_elapsed, self.cpu_elapsed});
    }
};

pub const Timer = struct {
    os_start: u64,
    cpu_start: u64,

    /// Creates a new instance of the Timer and starts the timer.
    pub fn initAndStart() Timer {
        return .{ .os_start = readOSTime(), .cpu_start = rdtsc() };
    }

    /// Starts the timer. Overrides the starting timestamps of the timer!
    pub fn start(self: *Timer) void {
        self.os_start = readOSTime();
        self.cpu_start = rdtsc();
    }

    /// Ends the timer and evaluates the results
    pub fn end(self: *Timer, comptime result_name: []const u8) TimerResult {

        const os_elapsed = readOSTime() - self.os_start;
        const cpu_elapsed = rdtsc() - self.cpu_start;

        self.cpu_start = 0;
        self.os_start = 0;

        if (os_elapsed == 0) {
            return TimerResult{.os_elapsed = 0, .cpu_elapsed = 0, .cpu_freq = 0, .name = result_name };
        }

        return TimerResult{
            .os_elapsed = os_elapsed,
            .cpu_elapsed = cpu_elapsed,
            .cpu_freq = os_timer_freq * cpu_elapsed / os_elapsed,
            .name = result_name
        };

    }

    /// Resets the timer timestamps to 0
    pub fn reset(self: *Timer) void {
        self.cpu_start = 0;
        self.os_start = 0;
    }

};

pub fn readOSTime() u64 {
    
    var timeval: std.posix.timeval = undefined;
    std.posix.gettimeofday(&timeval, null);

    return os_timer_freq * @as(u64, @bitCast(timeval.tv_sec)) + @as(u64, @bitCast(timeval.tv_usec));
}

pub fn rdtsc() u64 {

    var hi: u64 = 0;
    var low: u64 = 0;

    asm volatile (
        \\rdtsc
        : [low] "={eax}" (low),
          [hi] "={edx}" (hi)
    );

    return (@as(u64, hi) << 32) | @as(u64, low);
}
