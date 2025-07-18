const std = @import("std");
const testing = std.testing;

pub fn wow() i32 {
    return 100;
}

test {
    try testing.expectEqual(100, wow());
}
