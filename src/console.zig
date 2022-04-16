const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const os = std.os;

// windows console api
extern "kernel32" fn SetConsoleOutputCP(cp: os.windows.UINT) bool;
extern "kernel32" fn ReadConsoleW(handle: os.fd_t, buffer: [*]u16, len: os.windows.DWORD, read: *os.windows.DWORD, input_ctrl: ?*anyopaque) bool;

var stdout: std.fs.File.Writer = undefined;
var stdin: std.fs.File.Reader = undefined;
var stdinHandle: os.fd_t = undefined;

pub fn init() void {
    stdout = std.io.getStdOut().writer();
    stdin = std.io.getStdIn().reader();
    stdinHandle = std.io.getStdIn().handle;
    if (comptime builtin.os.tag == .windows) {
        _ = SetConsoleOutputCP(65001);
    }
}

pub fn print(bytes: []const u8) void {
    _ = stdout.write(bytes) catch unreachable;
}
pub fn println(bytes: []const u8) void {
    _ = stdout.write(bytes) catch unreachable;
    _ = stdout.write("\n") catch unreachable;
}
pub fn printf(comptime format: []const u8, args: anytype) void {
    stdout.print(format, args) catch unreachable;
}

pub fn readByte() u8 {
    return stdin.readByte() catch unreachable;
}

pub fn readLine(allocator: mem.Allocator) ![]u8 {
    const maxLen = 256;
    if (comptime builtin.os.tag == .windows) {
        var readBuf: [maxLen]u16 = undefined;
        var readCount: u32 = undefined;
        _ = ReadConsoleW(stdinHandle, &readBuf, readBuf.len, &readCount, null);

        var utf8Buf: [1024]u8 = undefined;
        const utf8Len = try std.unicode.utf16leToUtf8(utf8Buf[0..], readBuf[0..readCount]);
        const trimmed = mem.trimRight(u8, utf8Buf[0..utf8Len], "\r\n"); // trim windows newline

        var result = try allocator.alloc(u8, trimmed.len);
        mem.copy(u8, result, trimmed);
        return result;
    } else {
        return try stdin.readUntilDelimiterAlloc(allocator, '\n', maxLen);
        //               ^^^^^^^^^^^^^^^^^^^^^^^
        //               └> WARN: Can't read Unicode from Windows console!
    }
}
