// Learning Zig!

const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const termio = @import("termio.zig");

pub fn title(comptime text: []const u8) void {
    const concated = "\n[" ++ text ++ "]";
    termio.println(concated ++ "\n" ++ "-" ** (concated.len - 1));
}

pub fn main() !void {
    // init general purpose allocator
    var gpallocator = std.heap.GeneralPurposeAllocator(.{}){};
    const galloc = gpallocator.allocator();
    defer _ = gpallocator.deinit();

    // init random number generator
    const rngSeed = @intCast(u64, std.time.timestamp());
    const rng = std.rand.DefaultPrng.init(rngSeed).random();

    // init console
    termio.init();

    title("block");
    {
        // block can return a value
        const someText = blk: {
            //           ^^^^ --> this is a name of a block
            if (true) {
                break :blk "wow"; // break out of `blk` and return "wow"
                //                   https://ziglang.org/documentation/master/#blocks
            } else {
                break :blk "hello";
            }
        };
        termio.println(someText);
    }

    title("loop");
    termio.println("while loop:");
    {
        var i: i64 = 0;
        while (i < 5) {
            defer i += 1;
            termio.printf("{d} ", .{i});
        }
        termio.println("");

        i = 0;
        while (i < 5) : (i += 1) {
            termio.printf("{d} ", .{i});
        }
        termio.println("");

        i = 0;
        while (i < 5) : ({
            termio.printf("{d} ", .{i});
            i += 1;
        }) {
            termio.print("! ");
        }
        termio.println("");
    }

    termio.println("\nfor loop:");
    {
        const string = "Hello world!";

        for (string) |character, index| {
            termio.printf("string[{d}]: {c}\n", .{ index, character });
        }

        for (string) |character| {
            termio.printf("{c} ", .{character});
        }
        termio.println("");

        for (string) |_, index| {
            termio.printf("{d} ", .{index});
        }
        termio.println("");
    }

    title("pointer");
    termio.println("\npointer:");
    {
        var num: i32 = 10;
        termio.printf("num: {d}\n", .{num});

        var numPtr: *i32 = undefined;
        //          ^^^^ --> pointer type
        numPtr = &num;
        //       ^^^^ --> pointer of variable num (just like c)
        numPtr.* += 5;
        //    ^^ --> dereference pointer

        termio.printf("num: {d}\n", .{num});
    }
    termio.println("\nimmutable dereference:");
    {
        var num: i32 = 0;
        const ptr: *const i32 = &num;
        //          ^^^^^^ --> immutable dereference
        //                     ptr.* = 1; <-- this is compile time error
        termio.printf("num: {d}\n", .{ptr.*});
    }
    termio.println("\nheap allocation:");
    {
        var heapInt = try galloc.create(i32);
        //                       ^^^^^^^^^^^ --> allocates a single item
        defer galloc.destroy(heapInt);
        //           ^^^^^^^^^^^^^^^^ --> deallocates a single item

        heapInt.* = 100;
        termio.printf("num: {d}\n", .{heapInt.*});
    }
    termio.println("\noptional pointer:");
    {
        var ptr: ?*i32 = null;
        //       ^ --> optional type (null is allowed)
        ptr = try galloc.create(i32);
        defer galloc.destroy(ptr.?);
        //                            ^^ --> unwraps optional (runtime error if null)

        ptr.?.* = 100;
        termio.printf("optional pointer value: {d}\n", .{ptr.?.*});

        if (ptr) |value| { // this also unwraps optional
            value.* = 10;
            termio.printf("optional pointer value: {d}\n", .{value.*});
        } else {
            termio.println("optional pointer value: null");
        }
    }

    title("array");
    {
        termio.println("array (stack allocated):");
        var array = [_]i64{ 1, 10, 100 }; // this array is mutable because it's declared as `var`
        //            ^^^ --> same as [3]i64 because it has 3 items
        for (array) |*item, i| {
            //       ^^^^^  ^
            //       |      └> current index
            //       └> get array[i] as a pointer (so that we can change its value)
            item.* = @intCast(i64, i) + 1;
            termio.printf("[{d}]: {d}\n", .{ i, item.* });
        }

        termio.println("\npointer to array:");
        const ptr = &array; // pointer to an array
        for (ptr) |item, i| {
            termio.printf("[{d}]: {d}\n", .{ i, item });
        }

        termio.println("\nslice:");
        const slice = array[0..]; // a slice is a pointer and a length (its length is known at runtime)
        //                  ^^^
        //                  └> from index 0 to the end
        for (slice) |item, i| {
            termio.printf("[{d}]: {d}\n", .{ i, item });
        }

        termio.println("\nmem.set:");
        mem.set(i64, &array, 0);
        //  ^^^^^^^^^^^^^^^^^^^ --> set every elements in array to 0
        for (array) |item, i| {
            termio.printf("[{d}]: {d}\n", .{ i, item });
        }

        termio.println("\ninit array with ** operator:");
        const array2 = [_]i64{ 1, 2 } ** 3;
        //                   ^^^^^^^^^^^^^ --> this will result: { 1, 2, 1, 2, 1, 2 }
        for (array2) |item, i| {
            termio.printf("[{d}]: {d}\n", .{ i, item });
        }
    }
    {
        termio.println("\narray (heap allocated):");
        termio.print(">> array length: ");
        var arrayLength: usize = undefined;
        while (true) {
            const input = try termio.readLine();
            // handle error
            arrayLength = fmt.parseInt(usize, input, 10) catch {
                termio.print(">> please input positive number: ");
                continue;
            };
            break;
        }

        const array = try galloc.alloc(i64, arrayLength);
        //                       ^^^^^ --> allocates array
        defer galloc.free(array);
        //           ^^^^ --> deallocates array

        termio.println("apply random values:");
        for (array) |*item, i| {
            item.* = rng.intRangeAtMost(i64, 1, 10); // generate random value
            termio.printf("[{d}]: {d}\n", .{ i, item.* });
        }
    }
    {
        termio.println("\nconcat array compiletime:");
        const concated = "wow " ++ "hey " ++ "yay";
        //                      ^^ --> compiletime array concatenation operator
        termio.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });
    }
    {
        termio.println("\nconcat array runtime:");
        const words = [_][]const u8{ "wow ", "hey ", "yay" };
        const concated = try mem.concat(galloc, u8, words[0..]);
        defer galloc.free(concated);
        termio.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });
    }

    title("terminal io");
    {
        termio.print(">> terminal input: ");
        const input = try termio.readLine();
        const trimmed = mem.trim(u8, input, "\r\n ");
        //                                   ^^ --> including '\r' is important in windows!
        //                                          https://github.com/ziglang/zig/issues/6754
        const concated = try mem.concat(galloc, u8, &[_][]const u8{ input, "!!!" });
        defer galloc.free(concated);

        termio.printf("input: {s}\nlen: {d}\n", .{ trimmed, trimmed.len });
        termio.printf("concated: {s}\nlen: {d}\n", .{ concated, concated.len });
    }

    title("struct");
    {
        // all structs are anonymous
        // see: https://ziglang.org/documentation/master/#Struct-Naming
        const SomeStruct = struct {
            num: i64 = 0,
            //       ^^^ --> default value
            text: []const u8, // no default value
        };

        var someStruct = SomeStruct{ .text = "" };
        //                           ^^^^^^^^^^
        //                           └-> this is necessary because `text` has no default value
        someStruct.num = 10;
        someStruct.text = "hello";
        termio.printf("num: {d}\n", .{someStruct.num});
        termio.printf("text: {s}\n", .{someStruct.text});

        var astruct: ReturnStruct() = undefined;
        //           ^^^^^^^^^^^^^^
        //           └-> function returning anonymous struct can be used as a type
        astruct = ReturnStruct(){};
        termio.printf("a: {d}\n", .{astruct.a});
        termio.printf("b: {d}\n", .{astruct.b});
    }

    title("error");
    {
        errTest() catch |err| {
            termio.printf("{s}\n", .{err});
        };
    }

    termio.println("\npress enter key to exit...");
    _ = termio.readByte();
}

fn ReturnStruct() type {
    return struct {
        a: i64 = 1,
        b: i64 = 10,
    };
}

fn errFn() !void {
    const Error = error{TestError};
    return Error.TestError;
}

fn errTest() !void {
    defer termio.println("defer: before error");
    errdefer termio.println("errdefer: before error");
    try errFn();
    defer termio.println("defer: after error");
    errdefer termio.println("errdefer: after error");
}
