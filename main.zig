// Learning Zig!

// Looking into Odin and Zig
// https://news.ycombinator.com/item?id=28440579


const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const printTitle = @import("consoleutils.zig").printTitle;
const winconsole = @import("winconsole.zig");
const ConsoleIO = winconsole.ConsoleIO;

pub fn main() !void {
    // Init arena allocator
    var arenaAllocInst = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arenaAllocInst.deinit();
    const arenaAlloc = &arenaAllocInst.allocator;

    // Init general purpose allocator
    var generalAllocInst = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = generalAllocInst.deinit();
    const generalAlloc = &generalAllocInst.allocator;

    // Init rng
    var rng = std.rand.DefaultPrng.init(@intCast(u64, std.time.timestamp())).random();

    // Init console
    ConsoleIO.init();

    try printTitle(arenaAlloc, "Block");
    {
        const someText = blk: {
            //           ^^^^ --> this is a name of a block.
            if (true) {
                break :blk "wow"; // break out of `blk` and return "wow".
                //                   https://ziglang.org/documentation/master/#blocks
            } else {
                break :blk "hello";
            }
        };
        ConsoleIO.writeLine(someText);

        // this is also possible.
        ConsoleIO.writeLine(blk: {
            if (false) {
                break :blk "wow";
            } else {
                break :blk "hello";
            }
        });
    }

    try printTitle(arenaAlloc, "Pointer");
    {
        var num: i32 = 10;
        // console.printLine("num: {d}", .{num});
        ConsoleIO.printLine("num: {d}", .{num});

        var numPtr: *i32 = undefined;
        //          ^^^^ --> pointer type.
        numPtr = &num;
        //       ^^^^ --> pointer of variable num.
        numPtr.* = 1;
        //    ^^ --> dereference pointer.

        ConsoleIO.printLine("num: {d}", .{num});
    }
    {
        var num: i32 = 10;
        const ptr1: *const i32 = &num;
        //          ^^^^^^ --> immutable dereferenced value.
        //                     ptr1.* = 1; (compile time error.)
        _ = ptr1;
    }
    {
        var heapInt = try generalAlloc.create(i32);
        //                             ^^^^^^ --> allocates a single item.
        defer generalAlloc.destroy(heapInt);
        //                 ^^^^^^^ --> deallocates a single item.

        heapInt.* = 100;
        ConsoleIO.printLine("num: {d}", .{heapInt.*});
    }
    {
        var ptr: ?*i32 = null;
        //       ^ --> optional type. (null is allowed.)
        ptr = try generalAlloc.create(i32);
        defer generalAlloc.destroy(ptr.?);
        //                            ^^ --> unwraps optional. (runtime error if null.)

        ptr.?.* = 100;
        ConsoleIO.printLine("optional pointer value: {d}", .{ptr.?.*});

        if (ptr) |value| { // this also unwraps optional
            value.* = 10;
            ConsoleIO.printLine("optional pointer value: {d}", .{value.*});
        } else {
            ConsoleIO.writeLine("optional pointer value: null");
        }
    }

    try printTitle(arenaAlloc, "Array");
    {
        var array = [3]i32{ 1, 2, 3 };
        //          ^^^ --> length of this array.
        for (array) |item, i| {
            ConsoleIO.printLine("[{d}]: {d}", .{ i, item });
        }

        mem.set(i32, &array, 0);
        for (array) |item, i| {
            ConsoleIO.printLine("[{d}]: {d}", .{ i, item });
        }
    }
    {
        ConsoleIO.writeLine("array:");
        var array = [_]i32{ 1, 10, 100 }; // this array is mutable because it's declared as `var`.
        //            ^^^ --> same as [3]i32 because it has 3 items.
        for (array) |*item, i| {
            //       ^^^^^  ^
            //       |      └> current index.
            //       └> get array[i] as a pointer. (so that we can change its value.)
            item.* = @intCast(i32, i) + 1;
            ConsoleIO.print("[{d}]: {d}\n", .{ i, item.* });
        }

        ConsoleIO.writeLine("array ptr:");
        const ptr = &array; // pointer to an array.
        for (ptr) |item, i| {
            ConsoleIO.printLine("[{d}]: {d}", .{ i, item });
        }

        ConsoleIO.writeLine("slice:");
        const slice = array[0..]; // a slice is a pointer and a length. (its length is known at runtime.)
        //                  ^^^
        //                  └> from index 0 to the end.
        for (slice) |item, i| {
            ConsoleIO.printLine("[{d}]: {d}", .{ i, item });
        }
    }
    {
        ConsoleIO.writeLine("heap allocated array");

        var arrayLength: usize = 0;
        ConsoleIO.write("array length: ");
        while (true) {
            const arrayLengthInput = try ConsoleIO.readLine(generalAlloc);
            defer generalAlloc.free(arrayLengthInput);

            arrayLength = fmt.parseInt(usize, arrayLengthInput, 10) catch {
                ConsoleIO.write("please input usize: ");
                continue;
            };
            break;
        }

        const array = try generalAlloc.alloc(i32, arrayLength);
        //                             ^^^^^ --> allocates array.
        defer generalAlloc.free(array);
        //                 ^^^^ --> deallocates array.

        ConsoleIO.writeLine("apply random values:");
        for (array) |*item, i| {
            item.* = rng.intRangeAtMost(i32, 1, 10); // generate random value
            ConsoleIO.printLine("[{d}]: {d}", .{ i, item.* });
        }
    }
    {
        ConsoleIO.writeLine("concat array:");
        const str = try mem.concat(generalAlloc, u8, &[_][]const u8{ "wow ", "hey ", "yay" });
        defer generalAlloc.free(str);

        ConsoleIO.writeLine(str);
        ConsoleIO.printLine("{d}", .{str.len});
    }

    try printTitle(arenaAlloc, "Console IO");
    {
        ConsoleIO.write("\nconsole input(std): ");
        const stdin = std.io.getStdIn().reader();
        const input: []u8 = try stdin.readUntilDelimiterAlloc(generalAlloc, '\n', 256);
        //                            ^^^^^^^^^^^^^^^^^^^^^^^
        //                            └> Warning! (zig 0.8.1)
        //                               Can't read Unicode from Windows stdin!
        defer generalAlloc.free(input);

        const trimmed = mem.trim(u8, input, "\r\n ");
        //                                   ^^
        //                                   └> including '\r' is important in windows!
        //                                      https://github.com/ziglang/zig/issues/6754
        const concated = try mem.concat(generalAlloc, u8, &[_][]const u8{ trimmed, "..." });
        defer generalAlloc.free(concated);

        ConsoleIO.printLine("input: {s}\nlen: {d}", .{ trimmed, trimmed.len });
        ConsoleIO.printLine("concated: {s}\nlen: {d}", .{ concated, concated.len });
    }
    {
        ConsoleIO.write("\nconsole input(win api): ");
        const input: []u8 = try ConsoleIO.readLine(generalAlloc);
        defer generalAlloc.free(input);

        const concated = try mem.concat(generalAlloc, u8, &[_][]const u8{ input, "..." }); // FIXME
        defer generalAlloc.free(concated);

        ConsoleIO.printLine("input: {s}\nlen: {d}", .{ input, input.len });
        ConsoleIO.printLine("concated: {s}\nlen: {d}", .{ concated, concated.len });
    }

    try printTitle(arenaAlloc, "Struct");
    {
        // all structs are anonymous.
        // see: https://ziglang.org/documentation/master/#Struct-Naming
        const SomeStruct = struct {
            num: i32 = 0,
            //       ^^^ --> default value.
            text: []const u8, // no default value.
        };

        var someStruct = SomeStruct{ .text = "" };
        //                           ^^^^^^^^^^
        //                           └-> this is necessary because `text` has no default value.
        someStruct.num = 10;
        someStruct.text = "hello";
        ConsoleIO.printLine("num: {d}", .{someStruct.num});
        ConsoleIO.printLine("text: {s}", .{someStruct.text});

        var astruct: ReturnStruct() = undefined;
        //         ^^^^^^^^^^^^^^^^
        //         └-> function returning anonymous struct can be used as a type.
        astruct = ReturnStruct(){};
        ConsoleIO.printLine("a: {d}", .{astruct.a});
        ConsoleIO.printLine("b: {d}", .{astruct.b});
    }

    try printTitle(arenaAlloc, "Error");
    {
        errTest() catch |err| {
            ConsoleIO.printLine("{s}", .{err});
        };
    }

    {
        ConsoleIO.writeLine("\npress any key to exit...");
        const stdin = std.io.getStdIn().reader();
        _ = try stdin.readByte();
    }
}

fn ReturnStruct() type {
    return struct {
        a: i32 = 1,
        b: i32 = 10,
    };
}

fn errFn() !void {
    const Error = error{TestError};
    return Error.TestError;
}

fn errTest() !void {
    defer ConsoleIO.writeLine("defer: before error");
    errdefer ConsoleIO.writeLine("errdefer: before error");
    try errFn();
    defer ConsoleIO.writeLine("defer: after error");
    errdefer ConsoleIO.writeLine("errdefer: after error");
}
