const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;

pub fn printTitle(allocator: *Allocator, title: []const u8) !void {
    const concated = try mem.concat(allocator, u8, &[_][]const u8{ "\n<- ", mem.trim(u8, title, "\n "), " ->\n" });
    const line = try allocator.alloc(u8, concated.len - 1);
    for (line[0..]) |*char, i| {
        char.* = if (i != line.len - 1) '-' else '\n';
    }

    const stdout = std.io.getStdOut().writer();
    _ = try stdout.write(concated);
    _ = try stdout.write(line);
}
