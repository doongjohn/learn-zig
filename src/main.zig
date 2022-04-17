// Learning Zig!

const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const os = std.os;

pub fn Term() type {
    return struct {
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

        // windows console api
        extern "kernel32" fn SetConsoleOutputCP(cp: os.windows.UINT) bool;
        extern "kernel32" fn ReadConsoleW(handle: os.fd_t, buffer: [*]u16, len: os.windows.DWORD, read: *os.windows.DWORD, input_ctrl: ?*anyopaque) bool;

        /// INFO: this function uses global buffer for the input!
        /// please copy the result if you want to keep the result
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
    };
}

const term = Term();

pub fn title(comptime text: []const u8) void {
    const concated = "\n[" ++ text ++ "]\n";
    const line = "-" ** (concated.len - 2);
    term.println("\n" ++ line ++ concated ++ line);
}

pub fn title2(comptime text: []const u8) void {
    term.println("\n[" ++ text ++ "]");
}

pub fn main() !void {
    // init general purpose allocator
    var gpallocator = std.heap.GeneralPurposeAllocator(.{}){};
    const galloc = gpallocator.allocator();
    defer _ = gpallocator.deinit();

    // init random number generator
    const rngSeed = @intCast(u64, std.time.timestamp());
    const rng = std.rand.DefaultPrng.init(rngSeed).random();

    // init terminal io
    term.init();

    title("block");
    {
        // block can return a value
        var someText = blk: {
            //         ^^^^ --> this is a name of a block
            if (true) {
                break :blk "wow";
                //    ^^^^^^^^^^ -->break out of `blk` and return "wow"
                //                  https://ziglang.org/documentation/master/#blocks
            } else {
                break :blk "hello";
            }
        };
        term.println(someText);
    }

    title("loop");
    {
        title2("while loop");
        var i: i64 = 0;
        while (i < 5) {
            defer i += 1;
            term.printf("{d} ", .{i});
        }
        term.println("");

        i = 0;
        while (i < 5) : (i += 1) {
            term.printf("{d} ", .{i});
        }
        term.println("");

        i = 0;
        while (i < 5) : ({
            term.printf("{d} ", .{i});
            i += 1;
        }) {
            term.print("! ");
        }
        term.println("");
    }
    {
        title2("for loop");
        const string = "Hello world!";

        for (string) |byte, index| {
            term.printf("string[{d}]: {c}\n", .{ index, byte });
        }

        for (string) |byte| {
            term.printf("{c} ", .{byte});
        }
        term.println("");

        for (string) |_, index| {
            term.printf("{d} ", .{index});
        }
        term.println("");
    }

    title("pointer");
    {
        title2("basic pointer");
        var num: i32 = 10;
        term.printf("num: {d}\n", .{num});

        var numPtr: *i32 = undefined;
        //          ^^^^ --> pointer type
        numPtr = &num;
        //       ^^^^ --> pointer of variable num (just like c)
        numPtr.* += 5;
        //    ^^ --> dereference pointer

        term.printf("num: {d}\n", .{num});
    }
    {
        title2("immutable dereference");
        var num: i32 = 20;
        var ptr: *const i32 = &num;
        //       ^^^^^^ --> immutable dereference
        //                     ptr.* = 1; <-- this is compile time error
        term.printf("num: {d}\n", .{ptr.*});
    }
    {
        title2("heap allocation");
        const heapInt = try galloc.create(i32);
        //                         ^^^^^^^^^^^ --> allocates a single item
        defer galloc.destroy(heapInt);
        //           ^^^^^^^^^^^^^^^^ --> deallocates a single item

        heapInt.* = 100;
        term.printf("num: {d}\n", .{heapInt.*});
    }
    {
        title2("optional pointer");
        var ptr: ?*i32 = null;
        //       ^ --> optional type (null is allowed)
        //             it is zero cost for the pointer
        ptr = try galloc.create(i32);
        defer galloc.destroy(ptr.?);
        //                      ^^ --> unwraps optional (runtime error if null)

        ptr.?.* = 100;
        term.printf("optional pointer value: {d}\n", .{ptr.?.*});

        if (ptr) |value| {
        //       ^^^^^^^ --> this unwraps ptr and the captured value is
        //                   only available in this block
            value.* = 10;
            term.printf("optional pointer value: {d}\n", .{value.*});
        } else {
            term.println("optional pointer value: null");
        }
    }

    title("array");
    {
        title2("basic array");
        var array = [_]i64{ 1, 10, 100 }; // this array is mutable because it is declared as `var`
        //          ^^^ --> same as [3]i64 because it has 3 items (zig can infer the length)
        for (array) |*item, i| {
            //       ^^^^^  ^
            //       |      └> current index
            //       └> get element as a pointer (so that we can change its value)
            item.* = @intCast(i64, i) + 1; // <-- type of array index is `usize`
            term.printf("[{d}]: {d}\n", .{ i, item.* });
        }

        title2("pointer to array");
        const ptr = &array; // pointer to an array
        for (ptr) |item, i| {
            term.printf("[{d}]: {d}\n", .{ i, item });
        }

        title2("slice");
        const slice = array[0..]; // a slice is a pointer and a length (its length is known at runtime)
        //                  ^^^
        //                  └> from index 0 to the end
        for (slice) |item, i| {
            term.printf("[{d}]: {d}\n", .{ i, item });
        }

        title2("mem.set");
        mem.set(@TypeOf(array[0]), &array, 0);
        //  ^^^ --> set every elements in array to 0
        for (array) |item, i| {
            term.printf("[{d}]: {d}\n", .{ i, item });
        }

        title2("init array pattern with ** operator");
        const array2 = [_]i64{ 1, 2 } ** 3;
        //                   ^^^^^^^^^^^^^ --> this will result: { 1, 2, 1, 2, 1, 2 }
        for (array2) |item, i| {
            term.printf("[{d}]: {d}\n", .{ i, item });
        }
    }
    {
        title2("heap allocated array");
        term.print(">> array length: ");
        var arrayLength: usize = undefined;
        while (true) {
            const input = try term.readLine();
            // handle error
            arrayLength = std.fmt.parseInt(usize, input, 10) catch {
                term.print(">> please input positive number: ");
                continue;
            };
            break;
        }

        const array = try galloc.alloc(i64, arrayLength);
        //                       ^^^^^ --> allocate array
        defer galloc.free(array);
        //           ^^^^ --> deallocate array

        title2("apply random values to the array elements");
        for (array) |*item, i| {
            item.* = rng.intRangeAtMost(i64, 1, 10); // generate random value
            term.printf("[{d}]: {d}\n", .{ i, item.* });
        }
    }
    {
        title2("concat array compiletime");
        const concated = "wow " ++ "hey " ++ "yay";
        //                      ^^ --> compiletime array concatenation operator
        term.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });
    }
    {
        title2("concat array runtime");
        const words = [_][]const u8{ "wow ", "hey ", "yay" };
        const concated = try mem.concat(galloc, u8, words[0..]);
        defer galloc.free(concated);
        term.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });
    }

    title("terminal io");
    {
        term.print(">> terminal input: ");
        const input = try term.readLine();
        const trimmed = mem.trim(u8, input, "\r\n ");
        //                                   ^^ --> including '\r' is important in windows!
        //                                          https://github.com/ziglang/zig/issues/6754
        const concated = try mem.concat(galloc, u8, &[_][]const u8{ input, "!!!" });
        defer galloc.free(concated);

        term.printf("input: {s}\nlen: {d}\n", .{ trimmed, trimmed.len });
        term.printf("concated: {s}\nlen: {d}\n", .{ concated, concated.len });
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
        term.printf("num: {d}\n", .{someStruct.num});
        term.printf("text: {s}\n", .{someStruct.text});

        var astruct: ReturnStruct() = undefined;
        //           ^^^^^^^^^^^^^^
        //           └-> function returning anonymous struct can be used as a type
        astruct = ReturnStruct(){};
        term.printf("a: {d}\n", .{astruct.a});
        term.printf("b: {d}\n", .{astruct.b});
    }

    title("error");
    {
        // TODO: learn more about errors
        title2("with error");
        _ = returnError(rng) catch |err| {
            term.printf("{s}\n", .{err});
        };
        title2("without error");
        _ = returnNoError(rng) catch |err| {
            term.printf("{s}\n", .{err});
        }
    }

    term.print("\npress enter to exit...");
    _ = term.readByte();
}

fn ReturnStruct() type {
    return struct {
        a: i64 = 1,
        b: i64 = 10,
    };
}

fn compareRandom(rng: std.rand.Random, comp: i64) !i64 {
    const Error = error{TestError};
    var randomNum = rng.intRangeAtMost(i64, 1, 2);
    if (randomNum < comp) {
        return randomNum;
    } else {
        return Error.TestError;
    }
}
fn returnError(rng: std.rand.Random) !i64 {
    errdefer term.println("errdefer");
    var num = try compareRandom(rng, 0);
    //        ^^^ -> `try` is equal to `someFunc() catch |err| return err;`
    //               so if it returns an error,
    //               code below here will not be executed
    return num;
}
fn returnNoError(rng: std.rand.Random) !i64 {
    errdefer term.println("errdefer");
    var num = try compareRandom(rng, 3);
    return num;
}
