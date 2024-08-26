const std = @import("std");
const assertm = @import("../assertf.zig").assertm;
const timer = @import("timer.zig");

pub const os_timer_freq: u64 = 1000000;

const max_anchors: u32 = 64;

const ProfileAnchor = struct {
    tsc_elapsed_root: u64 = 0,
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
const is_profiling_on: bool = true;

const ProfileBlock = struct {
    tsc_start: u64 = 0,
    tsc_old_elapsed_root: u64 = 0,
    anchor_id: u64 = 0,
    parent_id: u64 = 0,
    label: []const u8 = "",

    pub fn end(self: *const ProfileBlock) void {

        switch (is_profiling_on) {
            inline true => {
                const tsc_end = timer.rdtsc();
                const elapsed = tsc_end - self.tsc_start;

                g_parent_id = self.parent_id;

                const anchor = &profiler.anchors[self.anchor_id];

                anchor.tsc_elapsed += elapsed;
                anchor.tsc_elapsed_root = self.tsc_old_elapsed_root + elapsed;
                anchor.label = self.label;
                profiler.anchors[g_parent_id].tsc_children += elapsed;
            },
            inline false => {},
        }

    }

};


pub fn beginProfiling() void {
    profiler.has_profiing_started = true;
    profiler.tsc_start = timer.rdtsc();
}

/// Starts up a profile block.
/// @param - Arbitrary label
/// @param - Anchor ID. THIS ONE IS SPECIFICALLY IMPORTANT. YOU CANNOT PASS JUST A REGULAR POINTER TO A NUMBER
/// Please use a static local variable to initialize a number before calling this function and pass the number's pointer
/// into the Anchor ID param!
/// 
/// for ex.
/// `const idx = struct { var curr: u64 = 0;};`
/// `const file_read = beginBlock("File Read", &idx.curr);`
pub fn beginBlock(comptime label: []const u8, idx: *u64) ProfileBlock {

    switch (is_profiling_on) {
        inline true => {
            if (idx.* == 0) {
                anchor_counter += 1;
                idx.* = anchor_counter;
            }

            var block = ProfileBlock{
                .label = label,
                .anchor_id = idx.*,
                .parent_id = g_parent_id,
                .tsc_old_elapsed_root = profiler.anchors[idx.*].tsc_elapsed_root
            };

            g_parent_id = idx.*;

            block.tsc_start = timer.rdtsc();
            return block;
        },
        inline false => return .{},
    }

}


pub fn endProfiling() !void {

    const total_end = timer.rdtsc();
    
    const total_tsc_elapsed: u64 = total_end - profiler.tsc_start;

    assertm(profiler.has_profiing_started, "You haven't started profiling!");

    const cpu_freq = estimateCPUFreq();
    const std_out = std.io.getStdOut().writer();

    const total_cpu_ms = 1000 * @as(f64, @floatFromInt(total_tsc_elapsed)) / @as(f64, @floatFromInt(cpu_freq));

    try std_out.print("Total Time - CPU: {d} ms\n", .{total_cpu_ms});

    switch (is_profiling_on) {
        inline true => {
            var unprofiled_cpu_ms: f64 = total_cpu_ms;
            var unprofiled_tsc_elapsed: u64 = total_tsc_elapsed;
            var unprofiled_portion: f64 = 1.0;
            
            for (0..profiler.anchors.len) |i| {

                if (profiler.anchors[i].tsc_elapsed > 0) {

                    const anchor = &profiler.anchors[i];

                    const anchor_tsc_elapsed = anchor.tsc_elapsed - anchor.tsc_children;

                    const anchor_cpu_ms: f64 = 1000 * @as(f64, @floatFromInt(anchor_tsc_elapsed)) / @as(f64, @floatFromInt(cpu_freq));
                    const anchor_portion: f64 = @as(f64, @floatFromInt(anchor_tsc_elapsed)) / @as(f64, @floatFromInt(total_tsc_elapsed));

                    try std_out.print("\t{s} | Elapsed: {d} ms ({d} cycles) ({d} %", .{anchor.label, anchor_cpu_ms, anchor_tsc_elapsed, 100.0 * anchor_portion});

                    if (anchor.tsc_elapsed_root != anchor_tsc_elapsed) {
                        try std_out.print(", {d} % w/children", .{100.0 * @as(f64, @floatFromInt(anchor.tsc_elapsed_root)) / @as(f64, @floatFromInt(total_tsc_elapsed))});
                    }

                    _ = try std_out.write(")\n");

                    unprofiled_cpu_ms -= anchor_cpu_ms;
                    unprofiled_tsc_elapsed -= anchor_tsc_elapsed;
                    unprofiled_portion -= anchor_portion;
                }

            }

            try std_out.print("\n\tUnprofiled | Elapsed {d} ms ({d} cycles) ({d} %)\n", .{unprofiled_cpu_ms, unprofiled_tsc_elapsed, unprofiled_portion * 100.0});

        },
        inline false => {},
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
