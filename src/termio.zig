// TODO: change this file to termutils.zig

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

const maxInput = 32768;
var inputBuf: [maxInput]u8 = undefined;
var inputBufUtf16: [maxInput]u16 = undefined;

pub fn init() void {
    stdout = std.io.getStdOut().writer();
    stdin = std.io.getStdIn().reader();
    stdinHandle = std.io.getStdIn().handle;
    if (comptime builtin.os.tag == .windows) {
        _ = SetConsoleOutputCP(65001);
    }
}

pub fn print(str: []const u8) void {
    _ = stdout.write(str) catch unreachable;
}
pub fn println(str: []const u8) void {
    _ = stdout.write(str) catch unreachable;
    _ = stdout.write("\n") catch unreachable;
}
pub fn printf(comptime format: []const u8, args: anytype) void {
    stdout.print(format, args) catch unreachable;
}

pub fn readByte() u8 {
    return stdin.readByte() catch unreachable;
}

/// INFO: this function uses same buffer for the input!
/// please copy the result if you want to store it in a different variable
pub fn readLine() ![]const u8 {
    if (comptime builtin.os.tag == .windows) {
        var readCount: u32 = undefined;
        _ = ReadConsoleW(stdinHandle, &inputBufUtf16, maxInput, &readCount, null);

        const len = try std.unicode.utf16leToUtf8(inputBuf[0..], inputBufUtf16[0..readCount]);
        return mem.trimRight(u8, inputBuf[0..len], "\r\n"); // trim windows newline
    } else {
        return try stdin.readUntilDelimiter(inputBuf[0..], '\n');
        //               ^^^^^^^^^^^^^^^^^^
        //               └> NOTE: Can't read Unicode from Windows console!
    }
}
