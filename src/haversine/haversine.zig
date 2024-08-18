const std = @import("std");

pub const Coordinates = struct {
    x0: f64,
    x1: f64,
    y0: f64,
    y1: f64,
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

pub fn generatePair(rand: *const std.rand.Random) Coordinates {
    return Coordinates{
        .x0 = rand.float(f64) * 360.0 - 180.0,
        .x1 = rand.float(f64) * 360.0 - 180.0,
        .y0 = rand.float(f64) * 180.0 - 90.0,
        .y1 = rand.float(f64) * 180.0 - 90.0,
    };
}
