const std = @import("std");
const os = std.os;
const mem = std.mem;
const unicode = std.unicode;

extern "kernel32" fn SetConsoleOutputCP(cp: os.windows.UINT) bool;
extern "kernel32" fn ReadConsoleW(handle: os.fd_t, buffer: [*]u16, len: os.windows.DWORD, read: *os.windows.DWORD, input_ctrl: ?*c_void) bool;

var stdinHandle: os.fd_t = undefined;
var stdout: std.fs.File.Writer = undefined;

pub const ConsoleIO = struct {
    pub fn init() ConsoleIO {
        _ = SetConsoleOutputCP(65001);
        stdout = std.io.getStdOut().writer();
        stdinHandle = std.io.getStdIn().handle;
        return ConsoleIO{};
    }

    const Self = @This();

    pub fn write(self: Self, bytes: []const u8) !void {
        _ = try stdout.write(bytes);
    }
    pub fn writeLine(self: ConsoleIO, bytes: []const u8) !void {
        _ = try stdout.write(bytes);
        _ = try stdout.write("\n");
    }

    pub fn print(self: Self, comptime format: []const u8, args: anytype) !void {
        try stdout.print(format, args);
    }
    pub fn printLine(self: Self, comptime format: []const u8, args: anytype) !void {
        try stdout.print(format, args);
        _ = try stdout.write("\n");
    }

    pub fn readLine(self: Self, allocator: *mem.Allocator) ![]u8 {
        var readBuff: [256]u16 = undefined;
        var readCount: u32 = undefined;
        _ = ReadConsoleW(stdinHandle, &readBuff, readBuff.len, &readCount, null);

        var utf8: [1024]u8 = undefined;
        const utf8Len = try unicode.utf16leToUtf8(&utf8, readBuff[0..readCount]);
        const trimmed = mem.trimRight(u8, utf8[0..utf8Len], "\r\n"); // trim windows newline.

        var result = try allocator.alloc(u8, trimmed.len);
        mem.copy(u8, result, trimmed);
        return result;
    }
};
