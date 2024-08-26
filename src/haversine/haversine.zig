const std = @import("std");
const parser = @import("../parser/json_parser.zig");
const profiler = @import("../profiler/profiler.zig");

pub const ValidationError = error {
    SchemaInvalid
};

pub const HaversineError = ValidationError || parser.ParseError || std.mem.Allocator.Error;

pub const Coordinates = struct {
    x0: f64 = 0.0,
    x1: f64 = 0.0,
    y0: f64 = 0.0,
    y1: f64 = 0.0,
};

pub inline fn square(a: f64) f64 {
    return a * a;
}

pub inline fn degreesToRadians(degrees: f64) f64 {
    return std.math.pi / 180.0 * degrees;
}

pub fn calculateHaversine(coords: *const Coordinates, radius: f64) f64 {
    var lat1: f64 = coords.y0;
    var lat2: f64 = coords.y1;
    const lon1: f64 = coords.x0;
    const lon2: f64 = coords.x1;

    const dLat: f64 = degreesToRadians(lat2 - lat1);
    const dLon: f64 = degreesToRadians(lon2 - lon1);

    lat1 = degreesToRadians(lat1);
    lat2 = degreesToRadians(lat2);

    const a: f64 = square(@sin(dLat / 2.0)) + @cos(lat1) * @cos(lat2) * square(@sin(dLon / 2.0));
    const c = 2.0 * std.math.asin(@sqrt(a));

    const result = radius * c;

    return result;
}

pub fn parseHaversinePairs(allocator: std.mem.Allocator, source: []u8)  HaversineError![]const Coordinates {
    var json_parser = parser.Parser.init(source);

    var json = try json_parser.parseJson(allocator);
    defer json.deinit(allocator);

    const idx = struct { var curr: u64 = 0;};
    const block = profiler.beginBlock("Validation", &idx.curr);
    defer block.end();

    var pair_array = std.ArrayList(Coordinates).init(allocator);
    defer pair_array.deinit();

    if (json.elements == null or json.elements.?.len != 1) {
        return HaversineError.SchemaInvalid;
    }

    const pairs_el = &json.elements.?[0];

    if (!std.mem.eql(u8, pairs_el.label, "pairs") or pairs_el.type != .array) {
        return ValidationError.SchemaInvalid;
    }

    if (pairs_el.elements == null) {
        return try pair_array.toOwnedSlice();
    }

    try pair_array.resize(pairs_el.elements.?.len);

    for (pairs_el.elements.?, 0..) |*el, i| {

        if (el.type != .object) {
            return ValidationError.SchemaInvalid;
        }

        var pair: Coordinates = .{};

        if (el.elements.?.len != 4) {
            std.debug.print("Failed to parse and validate! Expected number of fields in pairs: {d}, Actual: {d}", .{4, el.elements.?.len});
            return ValidationError.SchemaInvalid;
        }
        
        for (el.elements.?) |*field| {

            if (std.mem.eql(u8, field.label, "x0")) {
                pair.x0 = std.fmt.parseFloat(f64, field.value) catch {
                    std.debug.print("Failed to parse a float: Failed string {s}",.{field.value});
                    return parser.ParseError.UnexpectedToken;
                };
                continue;
            }

            if (std.mem.eql(u8, field.label, "x1")) {
                pair.x1 = std.fmt.parseFloat(f64, field.value) catch {
                    std.debug.print("Failed to parse a float: Failed string {s}",.{field.value});
                    return parser.ParseError.UnexpectedToken;
                };
                continue;
            }

            if (std.mem.eql(u8, field.label, "y0")) {
                pair.y0 = std.fmt.parseFloat(f64, field.value) catch {
                    std.debug.print("Failed to parse a float: Failed string {s}",.{field.value});
                    return parser.ParseError.UnexpectedToken;
                };
                continue;
            }

            if (std.mem.eql(u8, field.label, "y1")) {
                pair.y1 = std.fmt.parseFloat(f64, field.value) catch {
                    std.debug.print("Failed to parse a float: Failed string {s}",.{field.value});
                    return parser.ParseError.UnexpectedToken;
                };
                continue;
            }

            return ValidationError.SchemaInvalid;
        }

        pair_array.items[i] = pair;
    }

    return try pair_array.toOwnedSlice();
}



pub fn generatePair(rand: *const std.rand.Random) Coordinates {
    return Coordinates{
        .x0 = rand.float(f64) * 360.0 - 180.0,
        .x1 = rand.float(f64) * 360.0 - 180.0,
        .y0 = rand.float(f64) * 180.0 - 90.0,
        .y1 = rand.float(f64) * 180.0 - 90.0,
    };
}
