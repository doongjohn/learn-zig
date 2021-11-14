// Learning Zig!

// Looking into Odin and Zig
// https://news.ycombinator.com/item?id=28440579

const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const console = @import("console.zig");

pub fn title(comptime text: []const u8) void {
    const concated = "\n[Learn]: " ++ text;
    console.println(concated ++ "\n" ++ "-" ** (concated.len - 1));
}

pub fn main() !void {
    // Init general purpose allocator
    var gallocObj = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gallocObj.deinit();
    const galloc = &gallocObj.allocator;

    // Init random number generator
    const rngSeed = @intCast(u64, std.time.timestamp());
    const rng = std.rand.DefaultPrng.init(rngSeed).random();

    // Init console
    console.init();

    title("Block");
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

    title("Loop");
    {
        console.println("while loop:");
        {
            var i: i64 = 0;
            while (i < 5) {
                defer i += 1;
                console.printf("{d} ", .{i});
            }
            console.println("");

            i = 0;
            while (i < 5) : (i += 1) {
                console.printf("{d} ", .{i});
            }
            console.println("");

            i = 0;
            while (i < 5) : ({
                console.printf("{d} ", .{i});
                i += 1;
            }) {
                console.print("! ");
            }
            console.println("");
        }

        console.println("\nfor loop:");
        {
            const string = "Hello world!";

            for (string) |character, index| {
                console.printf("string[{d}] == {c}\n", .{ index, character });
            }

            for (string) |character| {
                console.printf("{c} ", .{character});
            }
            console.println("");

            for (string) |_, index| {
                console.printf("{d} ", .{index});
            }
            console.println("");
        }
    }

    title("Pointer");
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
        var heapInt = try galloc.create(i32);
        //                             ^^^^^^ --> allocates a single item
        defer galloc.destroy(heapInt);
        //                 ^^^^^^^ --> deallocates a single item

        heapInt.* = 100;
        console.printf("num: {d}\n", .{heapInt.*});
    }
    {
        var ptr: ?*i32 = null;
        //       ^ --> optional type (null is allowed)
        ptr = try galloc.create(i32);
        defer galloc.destroy(ptr.?);
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

    title("Array");
    {
        console.println("array (stack allocated):");
        var array = [_]i64{ 1, 10, 100 }; // this array is mutable because it's declared as `var`
        //            ^^^ --> same as [3]i64 because it has 3 items
        for (array) |*item, i| {
            //       ^^^^^  ^
            //       |      └> current index
            //       └> get array[i] as a pointer (so that we can change its value)
            item.* = @intCast(i64, i) + 1;
            console.printf("[{d}]: {d}\n", .{ i, item.* });
        }

        console.println("\narray ptr:");
        const ptr = &array; // pointer to an array
        for (ptr) |item, i| {
            console.printf("[{d}]: {d}\n", .{ i, item });
        }

        console.println("\nslice:");
        const slice = array[0..]; // a slice is a pointer and a length (its length is known at runtime)
        //                  ^^^
        //                  └> from index 0 to the end
        for (slice) |item, i| {
            console.printf("[{d}]: {d}\n", .{ i, item });
        }

        console.println("\nmem.set:");
        mem.set(i64, &array, 0);
        //  ^^^^^^^^^^^^^^^^^^^ --> set every elements in array to zero
        for (array) |item, i| {
            console.printf("[{d}]: {d}\n", .{ i, item });
        }
    }
    {
        console.println("\narray (heap allocated):");
        console.print(">> array length: ");
        var arrayLength: usize = 0;
        while (true) {
            const arrayLengthInput = try console.readLine(galloc);
            defer galloc.free(arrayLengthInput);
            arrayLength = fmt.parseInt(usize, arrayLengthInput, 10) catch {
                // handle error
                console.print("please input positive number: ");
                continue;
            };
            break;
        }

        const array = try galloc.alloc(i64, arrayLength);
        //                             ^^^^^ --> allocates array
        defer galloc.free(array);
        //                 ^^^^ --> deallocates array

        console.println("apply random values:");
        for (array) |*item, i| {
            item.* = rng.intRangeAtMost(i64, 1, 10); // generate random value
            console.printf("[{d}]: {d}\n", .{ i, item.* });
        }
    }
    {
        console.println("\nconcat array comptime:");
        const concated = "wow " ++ "hey " ++ "yay";
        console.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });
    }
    {
        console.println("\nconcat array runtime:");
        const words = [_][]const u8{ "wow ", "hey ", "yay" };
        const concated = try mem.concat(galloc, u8, words[0..]);
        defer galloc.free(concated);
        console.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });
    }

    title("Console IO");
    {
        console.print(">> console input: ");
        const input = try console.readLine(galloc);
        defer galloc.free(input);

        const trimmed = mem.trim(u8, input, "\r\n ");
        //                                   ^^ --> including '\r' is important in windows!
        //                                          https://github.com/ziglang/zig/issues/6754
        const concated = try mem.concat(galloc, u8, &[_][]const u8{ input, "!!!" });
        defer galloc.free(concated);

        console.printf("input: {s}\nlen: {d}\n", .{ trimmed, trimmed.len });
        console.printf("concated: {s}\nlen: {d}\n", .{ concated, concated.len });
    }

    title("Struct");
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
        console.printf("num: {d}\n", .{someStruct.num});
        console.printf("text: {s}\n", .{someStruct.text});

        var astruct: ReturnStruct() = undefined;
        //         ^^^^^^^^^^^^^^^^
        //         └-> function returning anonymous struct can be used as a type
        astruct = ReturnStruct(){};
        console.printf("a: {d}\n", .{astruct.a});
        console.printf("b: {d}\n", .{astruct.b});
    }

    title("Error");
    {
        errTest() catch |err| {
            console.printf("{s}\n", .{err});
        };
    }

    console.println("\npress enter key to exit...");
    _ = console.readByte();
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
    defer console.println("defer: before error");
    errdefer console.println("errdefer: before error");
    try errFn();
    defer console.println("defer: after error");
    errdefer console.println("errdefer: after error");
}
