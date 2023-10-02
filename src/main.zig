// https://ziglang.org/documentation/master/
// https://www.openmymind.net/Zig-Quirks/

const builtin = @import("builtin");
const native_arch = builtin.cpu.arch;

const std = @import("std");
const mem = std.mem;
const os = std.os;

const term = struct {
    var stdout: std.fs.File.Writer = undefined;
    var stdin: std.fs.File.Reader = undefined;
    var stdin_handle: os.fd_t = undefined;

    // cross compile to windows: zig build -Dtarget=x86_64-windows
    // windows console api (easy c interop!)
    const WINAPI: std.builtin.CallingConvention = if (native_arch == .x86) .Stdcall else .C;
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
        _ = stdout.write(str) catch |err| std.debug.panic("stdout.write error: {?}", .{err});
    }
    pub fn println(str: []const u8) void {
        _ = stdout.write(str) catch |err| std.debug.panic("stdout.write error: {?}", .{err});
        _ = stdout.write("\n") catch |err| std.debug.panic("stdout.write error: {?}", .{err});
    }
    pub fn printf(comptime format: []const u8, args: anytype) void {
        stdout.print(format, args) catch |err| std.debug.panic("stdout.print error: {?}", .{err});
    }

    const input_max = 32768;
    var input_buf: [input_max]u8 = undefined;
    var input_buf_utf16: [input_max]u16 = undefined;

    /// INFO: this function uses global buffer for the input!
    /// please copy the result if you want to keep the result
    pub fn readLine() ![]const u8 {
        if (comptime builtin.os.tag == .windows) {
            var readCount: u32 = undefined;
            if (!ReadConsoleW(stdin_handle, &input_buf_utf16, input_max, &readCount, null))
                return error.ReadConsoleFailed;

            const len = try std.unicode.utf16leToUtf8(&input_buf, input_buf_utf16[0..readCount]);
            //                          ^^^^^^^^^^^^^
            //                          └> windows uses utf16 internally so you need to convert it to utf8 which zig uses
            return mem.trimRight(u8, input_buf[0..len], "\r\n");
            //                                           ^^^^ --> also trim windows '\r'
        } else {
            return try stdin.readUntilDelimiter(&input_buf, '\n');
            //               ^^^^^^^^^^^^^^^^^^
            //               └> NOTE: Can't read Unicode from Windows console! (use windows ReadConsoleW)
        }
    }
};

pub fn h1(comptime text: []const u8) void {
    term.println("\n\x1b[;92m" ++ "# " ++ text ++ "\x1b[0m");
}

pub fn h2(comptime text: []const u8) void {
    term.println("\n\x1b[;32m" ++ "## " ++ text ++ "\x1b[0m");
}

pub fn main() !void {
    // init general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok); // detect memory leak
    const galloc = gpa.allocator();

    // // use c allocator for valgrind
    // var gpa = std.heap.c_allocator;
    // const galloc = gpa;

    // init terminal io
    term.init();

    h1("variable");
    {
        var n: u8 = 0b0000_0_1_01;
        //          ^^^^^^^^^^^^^ --> "_" can be used anywhere in a
        //                            number literal for better readability
        term.printf("{d}\n", .{n});

        const imm = 10;
        // imm = 100; // <-- error: cannot assign to constant
        term.printf("{d}\n", .{imm});
    }

    h1("block");
    {
        // block can return a value
        var some_text = some_block: {
            //          ^^^^^^^^^^^ --> this is a name of this block
            if (true) {
                break :some_block "wow"; // --> break out of this block and return "wow"
                //                              https://ziglang.org/documentation/master/#blocks
            } else {
                break :some_block "hello";
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
        term.printf("while end: i = {d}\n", .{i});
        term.println("");

        i = 0;
        while (i < 5) : (i += 1) {
            term.printf("{d} ", .{i});
        }
        term.printf("while end: i = {d}\n", .{i});
        term.println("");

        i = 0;
        while (i < 5) : ({
            term.print("(while : ())\n");
            i += 1;
        }) {
            defer term.print("(defer) ");
            term.printf("while body: {d} ", .{i});
        }
        term.printf("while end: i = {d}\n", .{i});
    }
    {
        h2("for loop");
        const string = "Hello world!";

        // range
        for (0..5) |i| { // 0 ~ 4
            term.printf("{} ", .{i});
        }
        term.println("");

        // get element
        for (string) |byte| {
            term.printf("{c} ", .{byte});
        }
        term.println("");

        // get index
        for (string, 0..) |_, index| {
            term.printf("{d} ", .{index});
        }
        term.println("");

        // get element and index
        for (string, 0..) |byte, index| {
            term.printf("string[{d}]: {c}\n", .{ index, byte });
        }

        // multi-object for loop
        var arr1 = [_]i32{ 1, 2, 3, 4, 5, 6 };
        var arr2 = [_]i32{ 2, 3, 4, 5, 6, 7, 8 };
        var arr3 = [_]i32{ 2, 3, 4, 5, 6, 7, 8, 9 };

        for (arr1, arr2[0..6], arr3[0..6]) |item1, item2, item3| {
            term.printf("arr1: {d}, arr2: {d} arr3: {d}\n", .{ item1, item2, item3 });
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
        //                  ptr.* = 1; <-- this is compile time error
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
        for (&array, 0..) |*item, i| {
            //             ^^^^^  ^
            //             |      └> current index
            //             └> get element as a pointer (so that we can change its value)
            item.* = @as(i64, @intCast(i)) + 1;
            //       ^^^^^^^^^^^^^^^^^^^^^ <-- type of the array index `i` is `usize`
            //                                 so I need to cast it to `i64`
            term.printf("[{d}]: {d}\n", .{ i, item.* });
        }

        h2("init array with ** operator");
        const array2 = [_]i64{ 1, 2, 3 } ** 3;
        //                   ^^^^^^^^^^^^^ --> this will create: { 1, 2, 3, 1, 2, 3, 1, 2, 3 }
        //                                     at compile time
        term.printf("{any}\n", .{array2});

        h2("assigning array to array");
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
        for (arr1_slice, 0..) |item, i| {
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
        for (arr_ptr, 0..) |item, i| {
            term.printf("[{d}]: {d}\n", .{ i, item });
        }

        h2("@memset");
        @memset(&array, 3); // --> set every elements in array to 3
        for (array, 0..) |item, i| {
            term.printf("[{d}]: {d}\n", .{ i, item });
        }
    }
    {
        h2("strings");

        // strings are just u8 array
        // (so handling Unicode is not trivial...)
        var yay = [_]u8{ 'y', 'a', 'y' };
        yay[0] = 'Y';
        term.println(yay[0..]);
        term.printf("{s}\n", .{@typeName(@TypeOf(yay))});

        // string literals are const slice to null terminated u8 array
        // read more: https://zig.news/kristoff/what-s-a-string-literal-in-zig-31e9
        // read more: https://zig.news/david_vanderson/beginner-s-notes-on-slices-arrays-strings-5b67
        var str_lit = "haha";
        term.printf("{s}\n", .{@typeName(@TypeOf(str_lit))});
        // (&str_lit[0]).* = 'A'; // <-- this is compile error because it's a const slice
        //                               very nice!

        // multiline string
        const msg =
            \\Hello, world!
            \\Zig is awesome!
            \\
        ;
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
        for (array, 0..) |*item, i| {
            item.* = @as(i64, @intCast(i));
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
        const input = mem.trim(u8, try term.readLine(), "\r\n ");
        //                                               ^^ --> including '\r' is important in windows!
        //                                                      https://github.com/ziglang/zig/issues/6754
        term.printf("input: {s}\nlen: {d}\n", .{ input, input.len });
        term.printf("unicode len: {d}\n", .{try std.unicode.utf8CountCodepoints(input)});

        // concat string
        const concated = try mem.concat(galloc, u8, &[_][]const u8{ input, "!!!" });
        defer galloc.free(concated);
        term.printf("concated: {s}\nlen: {d}\n", .{ concated, concated.len });
        term.printf("unicode len: {d}\n", .{try std.unicode.utf8CountCodepoints(concated)});
    }

    h1("struct");
    {
        // all structs are anonymous
        // see: https://ziglang.org/documentation/master/#Struct-Naming
        const SomeStruct = struct {
            num: i64 = 0,
            //       ^^^ --> default value
            text: []const u8, // <-- no default value
        };

        var some_struct = SomeStruct{ .text = "" }; // initalize struct by `StructName{}`
        //                            ^^^^^^^^^^
        //                            └-> this is necessary because `text` has no default value
        some_struct.num = 10;
        some_struct.text = "hello";
        term.printf("num: {d}\n", .{some_struct.num});
        term.printf("text: {s}\n", .{some_struct.text});

        var astruct: FunctionThatReturnsType() = undefined;
        //           ^^^^^^^^^^^^^^^^^^^^^^^
        //           └-> function returning anonymous struct can be used as a type
        astruct = FunctionThatReturnsType(){};
        term.printf("a: {d}\n", .{astruct.a});
        term.printf("b: {d}\n", .{astruct.b});

        // result location semantics
        // https://www.youtube.com/watch?v=dEIsJPpCZYg
        var s: struct { a: i32, b: i32 } = .{
            .a = 10,
            .b = 20,
        };
        term.printf("s: {}\n", .{s});
        s = .{
            .a = 50, // <-- writes 50 to s.a
            .b = s.a, // <-- writes s.a to s.b so it becomes 50
        };
        term.printf("s: {}\n", .{s});

        h2("tuple");
        // anonymous structs can be used as a tuple
        // https://ziglang.org/documentation/master/#Tuples
        var tuple = .{ @as(i32, 100), "yo" };
        term.printf("{d}\n", .{tuple[0]});
        term.printf("{s}\n", .{tuple[1]});

        // structs can be combined at compiletime
        var tuple2 = tuple ++ .{"wow"};
        term.printf("{d}\n", .{tuple2[0]});
        term.printf("{s}\n", .{tuple2[1]});
        term.printf("{s}\n", .{tuple2[2]});
    }

    h1("destructuring");
    {
        // destructuring can be done with
        // * Tuples
        // * Arrays
        // * Vectors

        var tuple = .{ @as(i32, 10), "hello" };
        var num, var str = tuple;
        term.printf("num = {d}\n", .{num});
        term.printf("str = {s}\n", .{str});

        var arr = [_]i32{ 1, 2, 3, 4 };
        var n1, var n2, _, _ = arr;
        term.printf("n1 = {d}\n", .{n1});
        term.printf("n2 = {d}\n", .{n2});
    }

    h1("lambda");
    {
        const TestLambda = struct {
            data: i32,

            fn func(self: @This()) void {
                term.printf("this is lambda, data = {d}\n", .{self.data});
            }
        };

        const a = 100;
        testLambdaCaller(TestLambda{ .data = a });
    }

    h1("enum");
    {
        const MyEnum = enum(u8) { Hello, Bye, _ };
        //                                    ^ --> non-exhaustive enum
        //                                          must use `else` in the switch

        var e: MyEnum = .Hello;

        switch (e) {
            .Hello => term.printf("{}\n", .{e}),
            .Bye => term.printf("{}\n", .{e}),
            else => term.println("other"),
        }
    }

    h1("random");
    {
        // init random number generator
        const rng_seed = @as(u64, @intCast(std.time.timestamp()));
        var rng_impl = std.rand.DefaultPrng.init(rng_seed);
        const random = rng_impl.random();

        for (0..3) |_| {
            const random_num = random.intRangeAtMost(i64, 1, 10); // generate random value
            term.printf("random between 1 ~ 10 => {}\n", .{random_num});
        }
    }

    h1("error & errdefer");
    {
        h2("with error");
        _ = returnError(true) catch |err| {
            term.printf("{!}\n", .{err});
        };

        h2("without error");
        _ = returnError(false) catch |err| {
            term.printf("{!}\n", .{err});
        };
    }

    h1("function pointer");
    {
        const f: *const fn () void = haha;
        f();
        term.printf("{s}\n", .{@typeName(@TypeOf(f))});

        // function alias
        const f2: fn () void = haha;
        f2();
        term.printf("{s}\n", .{@typeName(@TypeOf(f2))});
    }

    h1("refiy type");
    {
        // https://github.com/ziglang/zig/blob/61b70778bdf975957d45432987dde16029aca69a/lib/std/builtin.zig#L228
        const MyInt = @Type(.{ .Int = .{
            .signedness = .signed,
            .bits = 32,
        } });

        var a: MyInt = 20;
        term.printf("{d}\n", .{a});
    }
}

fn haha() void {
    std.debug.print("haha\n", .{});
}

fn FunctionThatReturnsType() type {
    return struct {
        a: i64 = 1,
        b: i64 = 10,
    };
}

fn testLambdaCaller(lambda: anytype) void {
    if (@TypeOf(@TypeOf(lambda).func) != fn (self: @TypeOf(lambda)) void)
        @compileError("lambda must have a function `fn func(self)`");

    lambda.func();
}

fn returnErrorAux(return_error: bool) !i64 {
    // const Error = error{TestError};
    if (return_error) {
        return error.TestError;
    } else {
        return 100;
    }
}

fn returnError(return_error: bool) !i64 {
    errdefer term.println("errdefer");
    var num = try returnErrorAux(return_error);
    //        ^^^ -> `try` is equal to `someFunc() catch |err| return err;`
    //               so if it returns an error,
    //               code below here will not be executed
    return num;
}
