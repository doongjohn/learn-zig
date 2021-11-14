// Learning Zig!

// Looking into Odin and Zig
// https://news.ycombinator.com/item?id=28440579

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const console = @import("console.zig");

pub fn title(comptime text: []const u8) !void {
    const concated = "\n[Learn]: " ++ text;
    console.println(concated ++ "\n" ++ "-" ** (concated.len - 1));
}

pub fn main() !void {
    // Init arena allocator
    // var arenaAllocObj = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arenaAllocObj.deinit();
    // const arenaAlloc = &arenaAllocObj.allocator;

    // Init general purpose allocator
    var generalAllocObj = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = generalAllocObj.deinit();
    const generalAlloc = &generalAllocObj.allocator;

    // Init rng
    var rng = std.rand.DefaultPrng.init(@intCast(u64, std.time.timestamp())).random();

    // Init console
    console.init();

    try title("Block");
    {
        const someText = blk: {
            //           ^^^^ --> this is a name of a block
            if (true) {
                break :blk "wow"; // break out of `blk` and return "wow"
                //                   https://ziglang.org/documentation/master/#blocks
            } else {
                break :blk "hello";
            }
        };
        console.println(someText);

        // this is also possible
        console.println(blk: {
            if (false) {
                break :blk "wow";
            } else {
                break :blk "hello";
            }
        });
    }

    try title("Pointer");
    {
        var num: i32 = 10;
        // console.printf("num: {d}", .{num});
        console.printf("num: {d}\n", .{num});

        var numPtr: *i32 = undefined;
        //          ^^^^ --> pointer type
        numPtr = &num;
        //       ^^^^ --> pointer of variable num
        numPtr.* = 1;
        //    ^^ --> dereference pointer

        console.printf("num: {d}\n", .{num});
    }
    {
        var num: i32 = 10;
        const ptr1: *const i32 = &num;
        //          ^^^^^^ --> immutable dereferenced value
        //                     ptr1.* = 1; (compile time error.)
        _ = ptr1;
    }
    {
        var heapInt = try generalAlloc.create(i32);
        //                             ^^^^^^ --> allocates a single item
        defer generalAlloc.destroy(heapInt);
        //                 ^^^^^^^ --> deallocates a single item

        heapInt.* = 100;
        console.printf("num: {d}\n", .{heapInt.*});
    }
    {
        var ptr: ?*i32 = null;
        //       ^ --> optional type. (null is allowed.)
        ptr = try generalAlloc.create(i32);
        defer generalAlloc.destroy(ptr.?);
        //                            ^^ --> unwraps optional (runtime error if null)

        ptr.?.* = 100;
        console.printf("optional pointer value: {d}\n", .{ptr.?.*});

        if (ptr) |value| { // this also unwraps optional
            value.* = 10;
            console.printf("optional pointer value: {d}\n", .{value.*});
        } else {
            console.println("optional pointer value: null");
        }
    }

    try title("Array");
    {
        var array = [3]i32{ 1, 2, 3 };
        //          ^^^ --> length of this array
        for (array) |item, i| {
            console.printf("[{d}]: {d}\n", .{ i, item });
        }

        mem.set(i32, &array, 0);
        for (array) |item, i| {
            console.printf("[{d}]: {d}\n", .{ i, item });
        }
    }
    {
        console.println("array:");
        var array = [_]i32{ 1, 10, 100 }; // this array is mutable because it's declared as `var`
        //            ^^^ --> same as [3]i32 because it has 3 items
        for (array) |*item, i| {
            //       ^^^^^  ^
            //       |      └> current index
            //       └> get array[i] as a pointer. (so that we can change its value.)
            item.* = @intCast(i32, i) + 1;
            console.printf("[{d}]: {d}\n", .{ i, item.* });
        }

        console.println("array ptr:");
        const ptr = &array; // pointer to an array
        for (ptr) |item, i| {
            console.printf("[{d}]: {d}\n", .{ i, item });
        }

        console.println("slice:");
        const slice = array[0..]; // a slice is a pointer and a length. (its length is known at runtime.)
        //                  ^^^
        //                  └> from index 0 to the end
        for (slice) |item, i| {
            console.printf("[{d}]: {d}\n", .{ i, item });
        }
    }
    {
        console.println("heap allocated array:");
        var arrayLength: usize = 0;

        console.print(">> array length: ");
        while (true) {
            const arrayLengthInput = try console.readLine(generalAlloc);
            defer generalAlloc.free(arrayLengthInput);
            arrayLength = fmt.parseInt(usize, arrayLengthInput, 10) catch {
                // handle error
                console.print("please input positive number: ");
                continue;
            };
            break;
        }

        const array = try generalAlloc.alloc(i32, arrayLength);
        //                             ^^^^^ --> allocates array
        defer generalAlloc.free(array);
        //                 ^^^^ --> deallocates array

        console.println("apply random values:");
        for (array) |*item, i| {
            item.* = rng.intRangeAtMost(i32, 1, 10); // generate random value
            console.printf("[{d}]: {d}\n", .{ i, item.* });
        }
    }
    {
        console.println("concat array comptime:");
        const concated = "wow " ++ "hey " ++ "yay";
        console.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });
    }
    {
        console.println("concat array alloc:");
        const words = [_][]const u8{ "wow ", "hey ", "yay" };
        const concated = try mem.concat(generalAlloc, u8, words[0..]);
        defer generalAlloc.free(concated);
        console.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });
    }

    try title("Console IO");
    {
        console.print(">> console input: ");
        const input = try console.readLine(generalAlloc);
        defer generalAlloc.free(input);

        const trimmed = mem.trim(u8, input, "\r\n ");
        //                                   ^^ --> including '\r' is important in windows!
        //                                          https://github.com/ziglang/zig/issues/6754
        const concated = try mem.concat(generalAlloc, u8, &[_][]const u8{ input, "!!!" });
        defer generalAlloc.free(concated);

        console.printf("input: {s}\nlen: {d}\n", .{ trimmed, trimmed.len });
        console.printf("concated: {s}\nlen: {d}\n", .{ concated, concated.len });
    }

    try title("Struct");
    {
        // all structs are anonymous
        // see: https://ziglang.org/documentation/master/#Struct-Naming
        const SomeStruct = struct {
            num: i32 = 0,
            //       ^^^ --> default value
            text: []const u8, // no default value
        };

        var someStruct = SomeStruct{ .text = "" };
        //                           ^^^^^^^^^^
        //                           └-> this is necessary because `text` has no default value
        someStruct.num = 10;
        someStruct.text = "hello";
        console.printf("num: {d}\n", .{someStruct.num});
        console.printf("text: {s}\n", .{someStruct.text});

        var astruct: ReturnStruct() = undefined;
        //         ^^^^^^^^^^^^^^^^
        //         └-> function returning anonymous struct can be used as a type
        astruct = ReturnStruct(){};
        console.printf("a: {d}\n", .{astruct.a});
        console.printf("b: {d}\n", .{astruct.b});
    }

    try title("Error");
    {
        errTest() catch |err| {
            console.printf("{s}\n", .{err});
        };
    }

    {
        console.println("\npress enter key to exit...");
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
    defer console.println("defer: before error");
    errdefer console.println("errdefer: before error");
    try errFn();
    defer console.println("defer: after error");
    errdefer console.println("errdefer: after error");
}
