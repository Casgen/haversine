const std = @import("std");
const assertm = @import("../assertf.zig").assertm;
const timer = @import("timer.zig");

pub const os_timer_freq: u64 = 1000000;

const max_anchors: u32 = 64;

const ProfileAnchor = struct {
    tsc_elapsed: u64 = 0,
    tsc_children: u64 = 0,
    label: []const u8 = "",
};

const Profiler = struct {
    has_profiing_started: bool = false,

    tsc_start: u64 = 0,

    anchors: [max_anchors]ProfileAnchor = [_]ProfileAnchor{.{}} ** max_anchors,
    anchors_count: u8 = 0,
};

var profiler = Profiler{};
var g_parent_id: u64 = 0;
var anchor_counter: u64 = 0;

const ProfileBlock = struct {
    tsc_start: u64 = 0,
    anchor_id: u64 = 0,
    parent_id: u64 = 0,
    label: []const u8 = "",


    pub fn endBlock(self: *ProfileBlock) void {

        const end = timer.rdtsc();

        g_parent_id = self.parent_id;

        const elapsed = end - self.tsc_start;

        profiler.anchors[g_parent_id].tsc_children += elapsed;
        profiler.anchors[self.anchor_id].tsc_elapsed += elapsed;
        profiler.anchors[self.anchor_id].label = self.label;

    }
};


pub fn beginProfiling() void {
    profiler.has_profiing_started = true;
    profiler.tsc_start = timer.rdtsc();
}

pub fn beginBlock(comptime label: []const u8) ProfileBlock {
    anchor_counter += 1;
    std.debug.assert(anchor_counter < profiler.anchors.len);

    var block: ProfileBlock = .{};

    block.parent_id = g_parent_id;
    block.anchor_id = anchor_counter;
    block.label = label;

    g_parent_id = block.anchor_id;

    block.tsc_start = timer.rdtsc();
    return block;
}



pub fn endProfiling() !void {

    const total_end = timer.rdtsc();
    const total_elapsed = total_end - profiler.tsc_start;

    assertm(profiler.has_profiing_started, "You haven't started profiling!");

    const cpu_freq = estimateCPUFreq();
    const std_out = std.io.getStdOut().writer();

    try std_out.print("Total Time - CPU: {d} ms\n", .{1000 * @as(f64, @floatFromInt(total_elapsed)) / @as(f64, @floatFromInt(cpu_freq))});
    
    for (0..profiler.anchors.len) |i| {

        if (profiler.anchors[i].tsc_elapsed > 0) {

            const anchor = &profiler.anchors[i];

            const cpu_timing: f64 = 1000 * @as(f64,@floatFromInt(anchor.tsc_elapsed - anchor.tsc_children)) / @as(f64,@floatFromInt(cpu_freq));
            const portion: f64 = @as(f64,@floatFromInt(anchor.tsc_elapsed - anchor.tsc_children)) / @as(f64,@floatFromInt(total_elapsed));

            try std_out.print("\t{s} | Elapsed: {d} ms ({d} cycles) ({d} %)\n", .{anchor.label, cpu_timing, anchor.tsc_elapsed, 100.0 * portion});
        }

    }

}

pub fn estimateCPUFreq() u64 {

    var elapsed: u64 = 0;
    var end: u64 = 0;
    const wait_time = timer.os_timer_freq * 100 / 1000;

    const cpu_start: u64 = timer.rdtsc();
    const start = timer.readOSTime();

    while (elapsed < wait_time) {
        end = timer.readOSTime();
        elapsed = end - start;
    }

    const cpu_end: u64 = timer.rdtsc();
    const cpu_elapsed: u64 = cpu_end - cpu_start;

    if (elapsed != 0) {
       return timer.os_timer_freq * cpu_elapsed / elapsed;
    }

    return 0;
}
