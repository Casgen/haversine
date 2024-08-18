const std = @import("std");
const haversine = @import("haversine/haversine.zig");
const assertm = @import("assertf.zig").assertm;
const assertf = @import("assertf.zig").assertf;
const parser = @import("parser/json_parser.zig");

const PairsObj = struct { pairs: []haversine.Coordinates };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();

    const arg = args.next();

    assertm(arg != null, "No arguments have been provided!");
    
    if (std.mem.eql(u8, arg.?, "--parse")) {
        try parse(allocator, &args);
        return;
    }

    const stdout = std.io.getStdOut().writer();

    // Get random seed argument
    var rand_seed: u64 = 718932478909;

    if (arg != null) {
        rand_seed = try std.fmt.parseInt(u64, arg.?, 0);
    }

    // Get Count of pair inputs argument
    var count: u64 = 1;
    const count_arg = args.next();

    if (count_arg != null) {
        count = try std.fmt.parseInt(u32, count_arg.?, 0);
    }

    const coords_array = try allocator.alloc(haversine.Coordinates, count);

    var pnrg = std.rand.DefaultPrng.init(rand_seed);
    const rand = pnrg.random();

    for (0..count) |i| {
        coords_array[i] = haversine.generatePair(&rand);
    }

    
    var json_stream = std.json.writeStream(stdout, .{ .whitespace =  .indent_4});

    try json_stream.beginObject();

    try json_stream.objectField("pairs");

    try json_stream.beginArray();

    for (coords_array) |item| {
        try json_stream.beginObject();

        try json_stream.objectField("x0");
        try json_stream.print("{d}", .{ item.x0 });

        try json_stream.objectField("x1");
        try json_stream.print("{d}", .{ item.x1 });

        try json_stream.objectField("y0");
        try json_stream.print("{d}", .{ item.y0 });
        
        try json_stream.objectField("y1");
        try json_stream.print("{d}", .{ item.y1 });

        try json_stream.endObject();
    }

    try json_stream.endArray();
    try json_stream.endObject();

    json_stream.deinit();
}

pub fn parse(allocator: std.mem.Allocator, args: *std.process.ArgIterator) !void {

    const input_json = args.next(); 

    assertm(input_json != null, "No input file has been provided!");

    const file_path: []const u8 = try std.fs.cwd().realpathAlloc(allocator, input_json.?);

    const file = std.fs.openFileAbsolute(file_path, .{.mode = .read_only}) catch {
        _ = try std.io.getStdErr().write("Failed to open the file");
        std.process.abort();
        return;
    };

    try file.seekFromEnd(0);

    const length = try file.getPos();
    const source = allocator.alloc(u8, length) catch |err| switch (err) {
        std.mem.Allocator.Error.OutOfMemory => { 
            _ = try std.io.getStdErr().write("Failed to allocate a buffer! Out of memory!");
            std.process.abort();
            return;
        }
    };

    try file.seekTo(0);

    const read_count = try file.readAll(source);

    assertf(read_count == length, "Failed to read the whole file! {d} != {d}", .{read_count, length});

    std.debug.print("{s}", .{source});

    _ = try parser.parseHaversinePairs(allocator, source);
}
