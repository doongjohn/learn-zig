const builtin = @import("builtin");
const native_arch = builtin.cpu.arch;

const std = @import("std");
const mem = std.mem;
const os = std.os;

const term = struct {
    var stdout: std.fs.File.Writer = undefined;
    var stdin: std.fs.File.Reader = undefined;
    var stdin_handle: os.fd_t = undefined;

    // windows console api (easy c interop!)
    const WINAPI: std.builtin.CallingConvention = if (native_arch == .i386) .Stdcall else .C;
    extern "kernel32" fn SetConsoleOutputCP(cp: os.windows.UINT) callconv(WINAPI) bool;
    extern "kernel32" fn ReadConsoleW(handle: os.fd_t, buffer: [*]u16, len: os.windows.DWORD, read: *os.windows.DWORD, input_ctrl: ?*anyopaque) callconv(WINAPI) bool;

    pub fn init() void {
        stdout = std.io.getStdOut().writer();
        stdin = std.io.getStdIn().reader();
        stdin_handle = std.io.getStdIn().handle;
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

    const input_max = 32768;
    var input_buf: [input_max]u8 = undefined;
    var input_buf_utf16: [input_max]u16 = undefined;

    /// INFO: this function uses global buffer for the input!
    /// please copy the result if you want to keep the result
    pub fn readLine() ![]const u8 {
        if (comptime builtin.os.tag == .windows) {
            var readCount: u32 = undefined;
            _ = ReadConsoleW(stdin_handle, &input_buf_utf16, input_max, &readCount, null);
            const len = try std.unicode.utf16leToUtf8(input_buf[0..], input_buf_utf16[0..readCount]);
            //                          ^^^^^^^^^^^^^
            //                          └> windows uses utf16 internally so I need to convert it to utf8
            return mem.trimRight(u8, input_buf[0..len], "\r\n"); // trim windows newline
        } else {
            return try stdin.readUntilDelimiter(input_buf[0..], '\n');
            //               ^^^^^^^^^^^^^^^^^^
            //               └> NOTE: Can't read Unicode from Windows console! (use windows ReadConsoleW)
        }
    }
};

pub fn h1(comptime text: []const u8) void {
    const str = "\n< " ++ text ++ " >\n";
    const line = "-" ** (str.len - 2);
    term.println("\n" ++ line ++ str ++ line);
}
pub fn h2(comptime text: []const u8) void {
    term.println("\n< " ++ text ++ " >");
}

pub fn main() !void {
    // init general purpose allocator
    var gpallocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpallocator.deinit();
    const galloc = gpallocator.allocator();

    // // use c allocator for valgrind
    // var gpallocator = std.heap.c_allocator;
    // const galloc = gpallocator;

    // // init random number generator
    // const rng_seed = @intCast(u64, std.time.timestamp());
    // const rng = std.rand.DefaultPrng.init(rng_seed).random();

    // init terminal io
    term.init();

    h1("variable");
    {
        var n: u8 = 0b0000_0_1_01;
        //          ^^^^^^^^^^^^^ --> "_" can be used anywhere in the number literals
        //                            for better readability
        term.printf("{d}\n", .{n});

        const imm = 10;
        // imm = 100; // <-- error: cannot assign to constant
        term.printf("{d}\n", .{imm});
    }

    h1("block");
    {
        // block is an expression (can return a value)
        var some_text = block_name: {
            //          ^^^ --> this is a name of this block
            if (true) {
                break :block_name "wow";
                //    ^^^^^^^^^^ --> break out of this block and return "wow"
                //                   https://ziglang.org/documentation/master/#blocks
            } else {
                break :block_name "hello";
            }
        };
        term.println(some_text);
    }

    h1("loop");
    {
        h2("while loop");
        var i: i64 = 0;

        i = 0;
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
        h2("for loop");
        const string = "Hello world!";

        // get element
        for (string) |byte| {
            term.printf("{c} ", .{byte});
        }
        term.println("");

        // get index
        for (string) |_, index| {
            term.printf("{d} ", .{index});
        }
        term.println("");

        // get element and index
        for (string) |byte, index| {
            term.printf("string[{d}]: {c}\n", .{ index, byte });
        }
    }
    {
        h2("for else");

        const string1 = "hello world";
        term.printf("find w in {s}\n", .{string1});
        const w1 = for (string1) |byte| {
            if (byte == 'w') {
                break byte;
            }
        } else blk: {
            // this runs when a for loop didn't break
            break :blk 'x';
        };
        term.printf("found: {c}\n", .{w1});

        const string2 = "hello";
        term.printf("find w in {s}\n", .{string2});
        term.println("if not found return \'x\'");
        const w2 = for (string2) |byte| {
            if (byte == 'w') {
                break byte;
            }
        } else blk: {
            // this runs when a for loop didn't break
            break :blk 'x';
        };
        term.printf("found: {c}\n", .{w2});
    }

    h1("pointer");
    {
        h2("basic pointer");
        var num: i32 = 10;
        term.printf("num: {d}\n", .{num});

        var num_ptr: *i32 = undefined;
        //           ^^^^ --> pointer type
        num_ptr = &num;
        //        ^^^^ --> pointer of variable num (just like c)
        num_ptr.* += 5;
        //     ^^ --> dereference pointer

        term.printf("num: {d}\n", .{num});
    }
    {
        h2("immutable dereference");
        var num: i32 = 20;
        var ptr: *const i32 = &num;
        //       ^^^^^^ --> immutable dereference
        //                     ptr.* = 1; <-- this is compile time error
        term.printf("num: {d}\n", .{ptr.*});
    }
    {
        h2("heap allocation");
        const heap_int = try galloc.create(i32);
        //                          ^^^^^^ --> allocates a single item
        defer galloc.destroy(heap_int);
        //           ^^^^^^^ --> deallocates a single item

        heap_int.* = 100;
        term.printf("num: {d}\n", .{heap_int.*});
    }
    {
        h2("optional(nullable) pointer");
        var ptr: ?*i32 = null;
        //       ^ --> optional type (null is allowed)
        //             it is zero cost for the pointer
        ptr = try galloc.create(i32);
        defer galloc.destroy(ptr.?);
        //                      ^^ --> unwraps optional (runtime error if null)

        ptr.?.* = 100;
        term.printf("optional pointer value: {d}\n", .{ptr.?.*});

        if (ptr) |value| {
            //   ^^^^^^^ --> this unwraps ptr and the captured value is
            //               only available in this block
            value.* = 10;
            term.printf("optional pointer value: {d}\n", .{value.*});
        } else {
            term.println("optional pointer value: null");
        }
    }

    h1("array");
    {
        h2("basic array");
        var array = [_]i64{ 1, 10, 100 }; // this array is mutable because it is declared as `var`
        //          ^^^ --> same as [3]i64 because it has 3 items (zig can infer the length)
        for (array) |*item, i| {
            //       ^^^^^  ^
            //       |      └> current index
            //       └> get element as a pointer (so that we can change its value)
            item.* = @intCast(i64, i) + 1; // <-- type of array index is `usize`
            term.printf("[{d}]: {d}\n", .{ i, item.* });
        }

        h2("init array pattern with ** operator");
        const array2 = [_]i64{ 1, 2, 3 } ** 3;
        //                   ^^^^^^^^^^^^^ --> this will create: { 1, 2, 3, 1, 2, 3, 1, 2, 3 }
        //                                     at compile time
        term.printf("{any}\n", .{array2});

        h2("array assign");
        // array gets copied when assigned
        var arr1 = [_]i32{ 0, 0, 0 };
        var arr2 = arr1;
        term.printf("arr1: {p}\n", .{&arr1[0]});
        term.printf("arr2: {p}\n", .{&arr2[0]});

        h2("slice");
        var arr1_slice = arr1[0..]; // a slice is a pointer and a length (its length is known at runtime)
        //                    ^^^
        //                    └> from index 0 to the end
        term.printf("arr1: {p}\n", .{&arr1[0]});
        term.printf("arr1_slice: {p}\n", .{&arr1_slice[0]});
        arr1_slice[0] = 10;
        for (arr1_slice) |item, i| {
            term.printf("[{d}]: {d}\n", .{ i, item });
        }
        term.printf("arr[0]: {d}\n", .{&arr1[0]});

        arr1_slice = &arr1;
        //           ^^^^^
        //           └> array pointer can be coerced to slice

        h2("pointer to array");
        const arr_ptr = &array; // pointer to an array
        term.printf("{s}\n", .{@typeName(@TypeOf(array))});
        term.printf("{s}\n", .{@typeName(@TypeOf(arr_ptr))});
        for (arr_ptr) |item, i| {
            term.printf("[{d}]: {d}\n", .{ i, item });
        }

        h2("mem.set");
        mem.set(@TypeOf(array[0]), &array, 3);
        //  ^^^ --> set every elements in array to 3
        for (array) |item, i| {
            term.printf("[{d}]: {d}\n", .{ i, item });
        }
    }
    {
        h2("strings");

        // strings are just u8 array
        var yay = [_]u8{ 'y', 'a', 'y' };
        yay[0] = 'Y';
        term.println(yay[0..]);

        // string literals are const slice to u8 array
        // read more: https://zig.news/kristoff/what-s-a-string-literal-in-zig-31e9
        // read more: https://zig.news/david_vanderson/beginner-s-notes-on-slices-arrays-strings-5b67
        var str_lit = "haha";
        term.printf("{s}\n", .{@typeName(@TypeOf(str_lit))});
        // (&str_lit[0]).* = 'A'; // <-- this is compile error because it's const slice
        //                               very nice!

        // multiline string
        const msg =
            \\Hello, world!
            \\Zig is awesome!
        ++ "\n";
        term.print(msg);
    }
    {
        h2("heap allocated array");
        term.print(">> array length: ");
        var array_length: usize = undefined;
        while (true) {
            const input = try term.readLine();
            // handle error
            array_length = std.fmt.parseInt(usize, input, 10) catch {
                term.print(">> please input positive number: ");
                continue;
            };
            break;
        }

        const array = try galloc.alloc(i64, array_length);
        //                       ^^^^^ --> allocate array
        defer galloc.free(array);
        //           ^^^^ --> deallocate array
        for (array) |*item, i| {
            item.* = @intCast(i64, i); // generate random value
        }
        term.printf("{any}\n", .{array});

        h2("std.ArrayList");
        // string builder like function with ArrayList
        var str_builder = std.ArrayList(u8).init(galloc);
        defer _ = str_builder.deinit();
        try str_builder.appendSlice("wow ");
        try str_builder.appendSlice("this is cool! ");
        try str_builder.appendSlice("super power!");
        term.printf("{s}\n", .{str_builder.items});

        // TODO: move this part to the random section
        // h2("apply random values to the array elements");
        // for (array) |*item| {
        //     item.* = rng.intRangeAtMost(i64, 1, 10); // generate random value
        // }
        // term.printf("{any}\n", .{array});
    }
    {
        h2("concat array compiletime");
        const concated = "wow " ++ "hey " ++ "yay";
        //                      ^^ --> compiletime array concatenation operator
        term.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });
    }
    {
        h2("concat array runtime");
        const words = [_][]const u8{ "wow ", "hey ", "yay" };
        const concated = try mem.concat(galloc, u8, words[0..]);
        defer galloc.free(concated);
        term.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });
    }

    h1("terminal io");
    {
        term.print(">> terminal input: ");
        const input = try term.readLine();
        const trimmed = mem.trim(u8, input, "\r\n ");
        //                                   ^^ --> including '\r' is important in windows!
        //                                          https://github.com/ziglang/zig/issues/6754
        term.printf("input: {s}\nlen: {d}\n", .{ trimmed, trimmed.len });

        // concat string
        const concated = try mem.concat(galloc, u8, &[_][]const u8{ input, "!!!" });
        defer galloc.free(concated);
        term.printf("concated: {s}\nlen: {d}\n", .{ concated, concated.len });
    }

    h1("struct");
    {
        // all structs are anonymous
        // see: https://ziglang.org/documentation/master/#Struct-Naming
        const SomeStruct = struct {
            num: i64 = 0,
            //       ^^^ --> default value
            text: []const u8, // no default value
        };

        var some_struct = SomeStruct{ .text = "" }; // initalize struct by `StructName{}`
        //                           ^^^^^^^^^^
        //                           └-> this is necessary because `text` has no default value
        some_struct.num = 10;
        some_struct.text = "hello";
        term.printf("num: {d}\n", .{some_struct.num});
        term.printf("text: {s}\n", .{some_struct.text});

        var astruct: ReturnStruct() = undefined;
        //           ^^^^^^^^^^^^^^
        //           └-> function returning anonymous struct can be used as a type
        astruct = ReturnStruct(){};
        term.printf("a: {d}\n", .{astruct.a});
        term.printf("b: {d}\n", .{astruct.b});
    }

    h1("error");
    {
        // TODO: learn more about errors
        h2("with error");
        _ = returnErrorFunc(true) catch |err| {
            term.printf("{!}\n", .{err});
        };
        h2("without error");
        _ = returnErrorFunc(false) catch |err| {
            term.printf("{!}\n", .{err});
        };
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

fn returnErrorAux(return_error: bool) !i64 {
    const Error = error{TestError};
    if (return_error) {
        return Error.TestError;
    } else {
        return 100;
    }
}
fn returnErrorFunc(return_error: bool) !i64 {
    errdefer term.println("errdefer");
    var num = try returnErrorAux(return_error);
    //        ^^^ -> `try` is equal to `someFunc() catch |err| return err;`
    //               so if it returns an error,
    //               code below here will not be executed
    return num;
}
