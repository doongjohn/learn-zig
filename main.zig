// zig version
// 0.6.0+9fe4c8923

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const printTitle = @import("consoleutils.zig").printTitle;
const winconsole = @import("winconsole.zig");

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
    var rng = std.rand.DefaultPrng.init(@intCast(u64, std.time.timestamp())).random;

    // Init console
    const console = winconsole.ConsoleIO.init();

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
        console.writeLine(someText);

        // this is also possible.
        console.writeLine(blk: {
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
        console.printLine("num: {}", .{num});

        var numPtr: *i32 = undefined;
        //          ^^^^ --> pointer type.
        numPtr = &num;
        //       ^^^^ --> pointer of variable num.
        numPtr.* = 1;
        //    ^^ --> dereference pointer.

        console.printLine("num: {}", .{num});
    }
    {
        var num: i32 = 10;
        const ptr1: *const i32 = &num;
        //          ^^^^^^ --> you can't change its dereferenced value.
        //                     ptr1.* = 1; (compile time error.)
    }
    {
        var heapInt = try generalAlloc.create(i32);
        //                             ^^^^^^ --> allocates a single item.
        defer generalAlloc.destroy(heapInt);
        //                 ^^^^^^^ --> deallocates a single item.

        heapInt.* = 100;
        console.printLine("num: {}", .{heapInt.*});
    }
    {
        var ptr: ?*i32 = null;
        //       ^ --> optional type. (null is allowed.)
        ptr = try generalAlloc.create(i32);
        defer generalAlloc.destroy(ptr.?);
        //                            ^^ --> unwraps optional. (runtime error if null.)

        ptr.?.* = 100;
        console.printLine("optional pointer value: {}", .{ptr.?.*});

        if (ptr) |value| { // this also unwraps optional
            value.* = 10;
            console.printLine("optional pointer value: {}", .{value.*});
        } else {
            console.writeLine("optional pointer value: null");
        }
    }

    try printTitle(arenaAlloc, "Array");
    {
        var array = [3]i32{ 1, 2, 3 };
        //          ^^^ --> length of this array.
        for (array) |item, i| {
            console.printLine("[{}]: {}", .{ i, item });
        }

        mem.set(i32, &array, 0);
        for (array) |item, i| {
            console.printLine("[{}]: {}", .{ i, item });
        }
    }
    {
        console.writeLine("array:");
        var array = [_]i32{ 1, 10, 100 }; // this array is mutable because it's declared as `var`.
        //            ^^^ --> same as [3]i32 because it has 3 items.
        for (array) |*item, i| {
            //       ^^^^^  ^
            //       |      └> current index.
            //       └> get array[i] as a pointer. (so that we can change its value.)
            item.* = @intCast(i32, i) + 1;
            console.print("[{}]: {}\n", .{ i, item.* });
        }

        console.writeLine("array ptr:");
        const ptr = &array; // pointer to an array.
        for (ptr) |item, i| {
            console.printLine("[{}]: {}", .{ i, item });
        }

        console.writeLine("slice:");
        const slice = array[0..]; // a slice is a pointer and a length. (its length is known at runtime.)
        //                  ^^^
        //                  └> from index 0 to the end.
        for (slice) |item, i| {
            console.printLine("[{}]: {}", .{ i, item });
        }
    }
    {
        console.writeLine("heap allocated array");

        var arrayLength: usize = 0;
        console.write("array length: ");
        while (true) {
            const arrayLengthInput = try console.readLine(generalAlloc);
            defer generalAlloc.free(arrayLengthInput);

            arrayLength = fmt.parseInt(usize, arrayLengthInput, 10) catch {
                console.write("please input usize: ");
                continue;
            };
            break;
        }

        const array = try generalAlloc.alloc(i32, arrayLength);
        //                             ^^^^^ --> allocates array.
        defer generalAlloc.free(array);
        //                 ^^^^ --> deallocates array.

        console.writeLine("apply random values:");
        for (array) |*item, i| {
            item.* = rng.intRangeAtMost(i32, 1, 10); // generate random value
            console.printLine("[{}]: {}", .{ i, item.* });
        }
    }
    {
        console.writeLine("concat array:");
        const str = try mem.concat(generalAlloc, u8, &[_][]const u8{ "wow ", "hey ", "yay" });
        defer generalAlloc.free(str);

        console.writeLine(str);
        console.printLine("{}", .{str.len});
    }

    try printTitle(arenaAlloc, "Console IO");
    {
        console.write("\nconsole input(std): ");
        const stdin = std.io.getStdIn().inStream();
        const input: []u8 = try stdin.readUntilDelimiterAlloc(generalAlloc, '\n', 256);
        //                            ^^^^^^^^^^^^^^^^^^^^^^^
        //                            └> Warning! (zig 0.6.0)
        //                               Can't read Unicode from Windows stdin!
        defer generalAlloc.free(input);

        const trimmed = fmt.trim(input);
        const concated = try mem.concat(generalAlloc, u8, &[_][]const u8{ trimmed, "..." });
        defer generalAlloc.free(concated);

        console.printLine("input: {}\nlen: {}", .{ trimmed, trimmed.len });
        console.printLine("concated: {}\nlen: {}", .{ concated, concated.len });
    }
    {
        console.write("\nconsole input(win api): ");
        const input: []u8 = try console.readLine(generalAlloc);
        defer generalAlloc.free(input);

        const concated = try mem.concat(generalAlloc, u8, &[_][]const u8{ input, "..." });
        defer generalAlloc.free(concated);

        console.printLine("input: {}\nlen: {}", .{ input, input.len });
        console.printLine("concated: {}\nlen: {}", .{ concated, concated.len });
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
        console.printLine("num: {}", .{someStruct.num});
        console.printLine("text: {}", .{someStruct.text});

        var astruct: returnStruct() = undefined;
        //         ^^^^^^^^^^^^^^^^
        //         └-> function returning anonymous struct can be used as a type.
        astruct = returnStruct(){};
        console.printLine("a: {}", .{astruct.a});
        console.printLine("b: {}", .{astruct.b});
    }

    try printTitle(arenaAlloc, "Error");
    {
        errTest(&console) catch |err| {
            console.printLine("{}", .{err});
        };
    }
}

fn returnStruct() type {
    return struct {
        a: i32 = 1,
        b: i32 = 10,
    };
}

fn errFn() !void {
    const Error = error{TestError};
    return Error.TestError;
}

fn errTest(console: *const winconsole.ConsoleIO) !void {
    defer console.writeLine("defer: before error");
    errdefer console.writeLine("errdefer: before error");
    try errFn();
    defer console.writeLine("defer: after error");
    errdefer console.writeLine("errdefer: after error");
}
