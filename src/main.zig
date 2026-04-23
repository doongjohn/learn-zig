const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const os = std.os;

const hello = struct {
    extern fn hello() void;
};

const win32 = if (builtin.os.tag == .windows) struct {
    const w = os.windows;

    extern "kernel32" fn SetConsoleOutputCP(wCodePageID: w.UINT) callconv(.winapi) w.BOOL;
    extern "kernel32" fn ReadConsoleW(handle: w.HANDLE, buffer: [*]u16, len: w.DWORD, read: *w.DWORD, input_ctrl: ?*anyopaque) callconv(.winapi) w.BOOL;
};

const console = struct {
    var stdout: std.Io.File.Writer = undefined;
    var stdin_buf: [256]u8 = @splat(0);

    var windows: if (builtin.os.tag == .windows) struct {
        stdin_handle: std.Io.File.Handle = undefined,
        stdin_buf_u16: [stdin_buf.len]u16 = @splat(0),
    } = .{};

    var posix: if (builtin.os.tag != .windows) struct {
        stdin: std.Io.File.Reader = undefined,
    } = .{};

    pub fn init(io: std.Io) void {
        stdout = std.Io.File.stdout().writerStreaming(io, &.{});

        switch (builtin.os.tag) {
            .windows => {
                windows.stdin_handle = std.Io.File.stdin().handle;
                const CP_UTF8 = 65001;
                _ = win32.SetConsoleOutputCP(CP_UTF8);
            },
            else => {
                posix.stdin = std.Io.File.stdin().readerStreaming(io, &stdin_buf);
            }
        }
    }

    pub fn print(str: []const u8) void {
        _ = stdout.interface.write(str) catch |err| std.debug.panic("stdout.write error: {}", .{err});
    }

    pub fn println(str: []const u8) void {
        _ = stdout.interface.write(str) catch |err| std.debug.panic("stdout.write error: {}", .{err});
        _ = stdout.interface.writeByte('\n') catch |err| std.debug.panic("stdout.writeByte error: {}", .{err});
    }

    pub fn printf(comptime format: []const u8, args: anytype) void {
        stdout.interface.print(format, args) catch |err| std.debug.panic("stdout.print error: {}", .{err});
    }

    /// This function stores the input string in a global buffer.
    /// You need to copy the result if you want to extend its lifetime.
    pub fn readLine() ![]const u8 {
        switch (builtin.os.tag) {
            .windows => {
                var read_count: u32 = 0;
                if (!win32.ReadConsoleW(windows.stdin_handle, &windows.stdin_buf_u16, windows.stdin_buf_u16.len, &read_count, null).toBool())
                    return error.ReadConsoleError;

                var pos: usize = 0;
                var high_surrogate: u16 = 0;
                var utf8_char_buf: [4]u8 = @splat(0);

                for (windows.stdin_buf_u16[0..read_count]) |utf16_char| {
                    if (pos >= stdin_buf.len) {
                        break;
                    }

                    if (high_surrogate == 0 and std.unicode.utf16IsHighSurrogate(utf16_char)) {
                        high_surrogate = utf16_char;
                        continue;
                    }

                    var len: usize = 0;
                    if (high_surrogate != 0 and std.unicode.utf16IsLowSurrogate(utf16_char)) {
                        len = try std.unicode.utf16LeToUtf8(&utf8_char_buf, &.{ high_surrogate, utf16_char });
                        high_surrogate = 0;
                    } else {
                        len = try std.unicode.utf16LeToUtf8(&utf8_char_buf, &.{utf16_char});
                    }

                    if (pos + len <= stdin_buf.len) {
                        @memcpy(stdin_buf[pos .. pos + len], utf8_char_buf[0..len]);
                        pos += len;
                    }
                }

                return mem.trimEnd(u8, stdin_buf[0..pos], "\r\n");
                //                                         ^^^^ --> Trim windows "\r\n".
            },
            else => {
                return try posix.stdin.interface.takeDelimiterExclusive('\n');
            },
        }
    }
};

pub fn h1(comptime text: []const u8) void {
    console.println("\n\x1b[;92m" ++ "# " ++ text ++ "\x1b[0m");
}

pub fn h2(comptime text: []const u8) void {
    console.println("\n\x1b[;32m" ++ "## " ++ text ++ "\x1b[0m");
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;

    console.init(io);

    h1("C interop");
    {
        hello.hello();
    }

    h1("terminal io");
    {
        console.print(">> terminal input: ");
        const input = mem.trim(u8, try console.readLine(), " \t");
        //                                                  ^^^ --> trim whitespace
        console.printf("input = {s}\n", .{input});
        console.printf("byte length = {d}\n", .{input.len});
        console.printf("utf8 codepoint length = {d}\n", .{try std.unicode.utf8CountCodepoints(input)});
    }

    h1("variable");
    {
        const n: u8 = 0b0000_0_1_01;
        //            ^^^^^^^^^^^^^ --> "_" can be used anywhere in a
        //                            numeric literal for better readability
        console.printf("{d}\n", .{n});

        const imm = 10;
        // imm = 100; // <-- error: cannot assign to constant
        console.printf("{d}\n", .{imm});
    }

    h1("block");
    {
        // block can return a value
        const some_text = some_block: {
            //            ^^^^^^^^^^^ --> This is the name of this block.
            if (true) {
                break :some_block "value"; // --> Break out of `some_block` and return "value"
                //                                https://ziglang.org/documentation/master/#blocks
            } else {
                break :some_block "hello";
            }
        };
        console.println(some_text);
    }

    h1("loop");
    {
        h2("while loop");
        var i: i64 = 0;

        i = 0;
        while (i < 5) {
            defer i += 1;
            console.printf("{d} ", .{i});
        }
        console.printf("while end: i = {d}\n", .{i});
        console.println("");

        i = 0;
        while (i < 5) : (i += 1) {
            console.printf("{d} ", .{i});
        }
        console.printf("while end: i = {d}\n", .{i});
        console.println("");

        i = 0;
        while (i < 5) : ({
            console.print("(while : ())\n");
            i += 1;
        }) {
            defer console.print("(defer) ");
            console.printf("while body: {d} ", .{i});
        }
        console.printf("while end: i = {d}\n", .{i});
    }
    {
        h2("for loop");
        const string = "Hello, world!";

        // Iterate range.
        for (0..5) |i| { // 0 ~ 4
            console.printf("{} ", .{i});
        }
        console.println("");

        // Iterate slices / arrays while capturing element.
        for (string) |byte| {
            console.printf("{c} ", .{byte});
        }
        console.println("");

        // Iterate slices / arrays while capturing index.
        for (string, 0..) |_, index| {
            console.printf("{d} ", .{index});
        }
        console.println("");

        // Iterate slices / arrays while capturing element and index.
        for (string, 0..) |byte, index| {
            console.printf("string[{d}]: {c}\n", .{ index, byte });
        }

        // multi-object for loop
        const arr1 = [_]i32{ 1, 2, 3, 4, 5, 6 };
        var arr2 = [_]i32{ 2, 3, 4, 5, 6, 7, 8 };
        var arr3 = [_]i32{ 2, 3, 4, 5, 6, 7, 8, 9 };

        for (arr1, arr2[0..6], arr3[0..6]) |item1, item2, item3| {
            console.printf("arr1: {d}, arr2: {d} arr3: {d}\n", .{ item1, item2, item3 });
        }
    }
    {
        h2("for else");

        const string1 = "Hello, world";
        console.printf("find w in {s}\n", .{string1});
        const w1 = for (string1) |byte| {
            if (byte == 'w') {
                break byte;
            }
        } else blk: {
            // This runs when this for loop didn't break.
            break :blk 'x';
        };
        console.printf("found: {c}\n", .{w1});

        const string2 = "hello";
        console.printf("find w in {s}\n", .{string2});
        console.println("if w is not found: return \'x\'");
        const w2 = for (string2) |byte| {
            if (byte == 'w') {
                break byte;
            }
        } else blk: {
            // This runs when this for loop didn't break.
            break :blk 'x';
        };
        console.printf("found: {c}\n", .{w2});
    }

    h1("pointer");
    {
        h2("basic pointer");
        var num: i32 = 10;
        console.printf("num: {d}\n", .{num});

        var num_ptr: *i32 = undefined;
        //           ^^^^ --> Pointer to i32.
        num_ptr = &num;
        //        ^^^^ --> Pointer of variable `num`. (Just like C)
        num_ptr.* += 5;
        //     ^^ --> Pointer dereferencing.

        console.printf("num: {d}\n", .{num});
    }
    {
        h2("immutable dereference");
        var num1: i32 = 10;
        var num2: i32 = 20;
        var ptr: *const i32 = &num1;
        //       ^^^^^^ --> Pointer to `const i32`.
        //                  ptr.* = 1; <-- this is compile time error because dereferenced type is `const i32`
        console.printf("ptr.*: {d}\n", .{ptr.*});
        ptr = &num2;
        console.printf("ptr.*: {d}\n", .{ptr.*});
    }
    {
        h2("heap allocation");
        const heap_int = try alloc.create(i32);
        //                         ^^^^^^ --> Allocates a single item.
        defer alloc.destroy(heap_int);
        //          ^^^^^^^ --> Deallocates a single item.

        heap_int.* = 100;
        console.printf("num: {d}\n", .{heap_int.*});
    }
    {
        // https://ziglang.org/documentation/master/#Optionals

        h2("optional(nullable) pointer");
        var opt_ptr: ?*i32 = null;
        //           ^ --> Optional type (nullable)
        //                 It's zero cost for the pointer.

        opt_ptr = try alloc.create(i32);
        defer if (opt_ptr) |ptr| alloc.destroy(ptr);

        opt_ptr.?.* = 100;
        //     ^^ --> Unwraps optional value (runtime error if null)
        console.printf("optional pointer value: {d}\n", .{opt_ptr.?.*});

        if (opt_ptr) |ptr| {
            //        ^^^ --> This is the unwrapped value of opt_ptr and this variable is
            //                only available in this scope.
            ptr.* = 10;
            console.printf("optional pointer value: {d}\n", .{ptr.*});
        } else {
            console.println("optional pointer value: null");
        }

        blk: {
            const ptr = opt_ptr orelse break :blk;
            //                  ^^^^^^ --> `a orelse b`
            //                             If a is null, returns b ("default value"), otherwise returns the unwrapped value of a.
            //                             Note that b may be a value of type noreturn.
            ptr.* += 10;
            console.printf("optional pointer value: {d}\n", .{ptr.*});
        }

        h2("function pointer & alias");
        {
            // Function pointer. (run-time)
            const f: *const fn () void = haha;
            f();
            console.printf("{s}\n", .{@typeName(@TypeOf(f))});

            // Function alias. (compile-time)
            const f2: fn () void = haha;
            f2();
            console.printf("{s}\n", .{@typeName(@TypeOf(f2))});
        }
    }

    h1("array");
    {
        h2("basic array");
        {
            var arr = [_]i64{ 1, 10, 100 }; // This array is mutable because it is declared as `var`.
            //        ^^^ --> Same as [3]i64 because it has 3 items. (zig can infer the length.)
            for (&arr, 0..) |*item, i| {
                //           ^^^^^  ^
                //           |      └> Current index. (usize)
                //           └> Capture the element as a pointer. (So that we can change its value.)
                item.* = @intCast(i + 1);
                console.printf("[{d}]: {d}\n", .{ i, item.* });
            }
        }

        h2("init array with ** operator");
        {
            const arr = [_]i64{ 1, 2, 3 } ** 3;
            //                ^^^^^^^^^^^^^^^^
            //                └> This will create: { 1, 2, 3, 1, 2, 3, 1, 2, 3 } at compile-time.
            console.printf("{any}\n", .{arr});
        }

        h2("assigning array to array");
        {
            var a1 = [_]i32{ 0, 0, 0 };
            var a2 = a1; // Arrays are copied when assigned.
            console.printf("a1: {p} != a2: {p}\n", .{ &a1[0], &a2[0] });

            // You can use this value semantics to copy a string literal into a variable.
            const str = "string on stack".*;
            console.printf("{s}\n", .{str});
        }

        h2("concat array compile-time");
        {
            const concated = "wow " ++ "hey " ++ "yay";
            //                      ^^ --> Compile-time array concatenation operator.
            console.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });
        }

        h2("slice");
        {
            var arr = [_]i32{ 0, 0, 0 };

            // Slice is a pointer and a length. (Its length is known at runtime.)
            var slice: []i32 = arr[0..];
            //                     ^^^
            //                     └> From index 0 to the end.
            //                    [n..m]
            //                     ^^^^
            //                     └> From index n to m-1.

            console.printf("&arr[0] == &slice[]: {}\n", .{&arr[0] == &slice[0]});

            // https://zig.guide/language-basics/slices/
            // When these n and m values are both known at compile time, slicing will actually produce a pointer to an array.
            // This is not an issue as a pointer to an array i.e. *[N]T will coerce to a slice - []T.

            slice = &arr;
            //      ^^^^
            //      └> Array pointer can be coerced to slice.
        }

        h2("pointer to array");
        {
            const arr = [_]i64{ 1, 2, 3 };
            const arr_ptr: *const [3]i64 = &arr; // Pointer to an array.

            // Zig allows iteration over a pointer to array.
            // So you don't need to write `arr_ptr.*`.
            for (arr_ptr, 0..) |item, i| {
                console.printf("[{d}]: {d}\n", .{ i, item });
            }
        }

        h2("@memset");
        {
            var arr: [3]i64 = undefined;
            @memset(&arr, 3); // --> Sets every element in the array to 3.
            for (arr, 0..) |item, i| {
                console.printf("[{d}]: {d}\n", .{ i, item });
            }
        }

        h2("@splat");
        {
            const arr: [3]i64 = @splat(3);
            //                  ^^^^^^^^^ --> Sets every element in the array to 3.
            //                                Unlike @memset(), which operates at runtime,
            //                                @splat() generates fully initialized data at compile time
            //                                and embeds it in the output binary. Which can increase binary size.
            //                                https://ziggit.dev/t/if-you-had-one-wish-for-zig-what-would-it-be/15069/42
            for (arr, 0..) |item, i| {
                console.printf("[{d}]: {d}\n", .{ i, item });
            }
        }

        h2("heap allocated array");
        {
            console.print(">> input array length: ");
            var arr_length: usize = undefined;
            while (true) {
                const input = try console.readLine();
                arr_length = std.fmt.parseInt(usize, input, 10) catch {
                    //                                          ^^^^^ --> Handle the error.
                    console.print(">> please input positive integer: ");
                    continue;
                };
                break;
            }

            const arr = try alloc.alloc(i64, arr_length);
            //                    ^^^^^ --> Allocate an array.
            defer alloc.free(arr);
            //          ^^^^ --> Deallocate an array.

            for (arr, 0..) |*item, i| {
                item.* = @intCast(i);
            }
            console.printf("{any}\n", .{arr});
        }

        h2("concat array run-time");
        {
            const words = [_][]const u8{ "wow ", "hey ", "yay" };
            const concated = try mem.concat(alloc, u8, words[0..]);
            defer alloc.free(concated);
            console.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });
        }

        h2("string");
        {
            // Strings are just array of u8.
            // (So handling Unicode is not trivial...)
            var yay = [_]u8{ 'y', 'a', 'y' };
            yay[0] = 'Y';
            console.println(yay[0..]);
            console.printf("{s}\n", .{@typeName(@TypeOf(yay))});

            // String literals are const slice to null terminated u8 array.
            // - https://zig.news/kristoff/what-s-a-string-literal-in-zig-31e9
            // - https://zig.news/david_vanderson/beginner-s-notes-on-slices-arrays-strings-5b67
            const str_lit = "this is a string literal";
            console.printf("{s}\n", .{@typeName(@TypeOf(str_lit))});
            // (&str_lit[0]).* = 'A'; // <-- This is compile-time error because it's a const slice.
            //                               Very nice!

            // Multiline string literal.
            const msg =
                \\Hello, world!
                \\Zig is awesome!
                \\
            ;
            console.print(msg);
        }

        h2("std.ArrayList");
        {
            // You can use `ArrayList(u8)` as a string builder.
            var str_builder = try std.ArrayList(u8).initCapacity(alloc, 0);
            defer str_builder.deinit(alloc);

            try str_builder.appendSlice(alloc, "wow ");
            try str_builder.appendSlice(alloc, "this is cool! ");
            try str_builder.appendSlice(alloc, "super power!");

            console.printf("{s}\n", .{str_builder.items});
        }
    }

    h1("enum");
    {
        const MyEnum = enum(u8) { Hello, Bye, _ };
        //                                    ^ --> This means MyEnum is a non-exhaustive enum.
        //                                          https://ziglang.org/documentation/master/#Non-exhaustive-enum

        const e: MyEnum = .Hello;
        switch (e) {
            .Hello => console.printf("{}\n", .{e}),
            .Bye => console.printf("{}\n", .{e}),
            else => console.println("other"), // Must use `else` when switching on non-exhaustive enum.
        }
    }

    h1("struct");
    {
        // All types including a struct is a value that can be stored in a comptime variable.
        // https://ziglang.org/documentation/master/#Struct-Naming
        const SomeStruct = struct {
            num: i64 = 0, // <-- This field has a default value.
            text: []const u8,
        };

        var some_struct = SomeStruct{ .text = "" };
        //                            ^^^^^^^^^^
        //                            └-> This is necessary because `text` has no default value.
        some_struct.num = 10;
        some_struct.text = "hello";
        console.printf("some_struct = {}\n", .{some_struct});
        console.printf("some_struct.text = {s}\n", .{some_struct.text});

        h2("function returning type");
        {
            var p1: Point2d() = undefined;
            var p2: Point2d() = undefined;
            //      ^^^^^^^^^
            //      └-> Function returning a type can be used as a type.
            p1 = Point2d(){ .x = 10, .y = 20 };
            p2 = Point2d(){ .x = 20, .y = 10 };
            console.printf("p1 = {}\n", .{p1});
            console.printf("Type of p1 and p2 is equal: {}\n", .{@TypeOf(p1) == @TypeOf(p2)});
        }

        h2("result location semantics");
        {
            // https://www.youtube.com/watch?v=dEIsJPpCZYg
            var f: struct { a: i32, b: i32 } = .{
                .a = 10,
                .b = 20,
            };
            console.printf("s: {}\n", .{f});
            f = .{
                .a = 50, // <-- Writes 50 to `s.a`.
                .b = f.a, // <-- Writes `s.a` to `s.b` so it becomes 50.
            };
            console.printf("s: {}\n", .{f});
        }

        h2("tuple");
        {
            // Struct without field names can be used as a tuple.
            // https://ziglang.org/documentation/master/#Tuples
            const tuple = .{ @as(i32, 100), "yo" };
            console.printf("[0]: {d}\n", .{tuple[0]});
            console.printf("[1]: {s}\n", .{tuple[1]});

            // Structs can be combined at compile-time.
            const tuple2 = tuple ++ .{"wow"};
            console.printf("[0]: {d}\n", .{tuple2[0]});
            console.printf("[1]: {s}\n", .{tuple2[1]});
            console.printf("[2]: {s}\n", .{tuple2[2]});
        }

        h2("Nested function");
        {
            // There is no nested function so you need to use a struct.
            const fn_wrapper = struct {
                fn nested_func() void {
                    console.println("nested fn");
                }
            };
            fn_wrapper.nested_func();
        }
    }

    h1("destructuring");
    {
        // Destructuring can be done with:
        // - Tuples
        // - Arrays
        // - Vectors

        const tuple = .{ @as(i32, 10), "hello" };
        const num, const str = tuple;
        console.printf("num = {d}\n", .{num});
        console.printf("str = {s}\n", .{str});

        const arr = [_]i32{ 1, 2, 3, 4 };
        const n1, const n2, _, _ = arr;
        console.printf("n1 = {d}\n", .{n1});
        console.printf("n2 = {d}\n", .{n2});
    }

    h1("error & errdefer");
    {
        blk1: {
            returnError(true) catch |err| {
                console.printf("{}\n", .{err});
                break :blk1;
            };
            console.print("no error\n");
        }

        blk2: {
            returnError(false) catch |err| {
                console.printf("{}\n", .{err});
                break :blk2;
            };
            console.print("no error\n");
        }
    }

    h1("closure with capture");
    {
        var a: i32 = 100;
        console.printf("before closure: a = {d}\n", .{a});

        runClosure(struct {
            // Closure captures.
            a: *i32,

            // Closure function.
            fn call(closure: @This()) void {
                closure.a.* += 100;
            }
        }{
            // Capturing variable.
            .a = &a,
        });

        console.printf("after closure: a = {d}\n", .{a});
    }

    h1("reify type");
    {
        // Type can be created at compile-time.
        // https://github.com/ziglang/zig/blob/master/lib/std/builtin.zig#L518
        const MyInt = @Int(.signed, 32);

        const n: MyInt = 20;
        console.printf("{d}\n", .{n});

        // Multiple unwrap using reify type.
        var opt_a: ?i32 = null;
        const opt_b: ?f32 = 2.2;
        if (unwrapAll(.{ opt_a, opt_b })) |unwrapped| {
            const a, const b = unwrapped;
            console.println("unwrap success");
            console.printf("a = {}, b = {}\n", .{ a, b });
        } else {
            console.println("unwrap failed");
        }

        opt_a = 10;
        if (unwrapAll(.{ opt_a, opt_b })) |unwrapped| {
            const a, const b = unwrapped;
            console.println("unwrap success");
            console.printf("a = {}, b = {}\n", .{ a, b });
        } else {
            console.println("unwrap failed");
        }
    }

    h1("random");
    {
        const seed: u64 = @bitCast(std.Io.Clock.now(.real, io).toSeconds());
        var rng = std.Random.DefaultPrng.init(seed);
        const random = rng.random();

        for (0..5) |_| {
            const num = random.intRangeAtMost(i64, 1, 10);
            console.printf("random 1 ~ 10 => {}\n", .{num});
        }
    }
}

fn haha() void {
    std.debug.print("haha\n", .{});
}

// Name of a function that returns a type should use PascalCase.
fn Point2d() type {
    return struct {
        x: i64 = 0,
        y: i64 = 0,
    };
}

inline fn typeCheckClosure(closure: anytype) void {
    const comptimePrint = std.fmt.comptimePrint;

    const Closure = @TypeOf(closure);
    if (@typeInfo(Closure) != .@"struct") {
        @compileError(comptimePrint("`closure` must be a `struct` but found: `{}`", .{Closure}));
    }
    if (!@hasDecl(Closure, "call")) {
        @compileError(comptimePrint("`closure` must have a decl `fn call(closure: @This)`", .{}));
    }

    const ClosureCall = @TypeOf(Closure.call);
    switch (@typeInfo(ClosureCall)) {
        .@"fn" => |func_info| {
            if (func_info.params.len != 1 or func_info.params[0].type != Closure) {
                @compileError(comptimePrint("`closure.call` must be a `fn call(closure: @This)` but found: `{}`", .{ClosureCall}));
            }
        },
        else => {
            @compileError(comptimePrint("`closure.call` must be a `fn call(closure: @This)` but found: `{}`", .{ClosureCall}));
        },
    }
}

fn runClosure(closure: anytype) void {
    typeCheckClosure(closure);
    closure.call();
}

fn returnErrorInner(return_error: bool) !void {
    // const Error = error{TestError}; // --> `error set`
    //                                        https://ziglang.org/documentation/master/#Errors
    if (return_error) {
        return error.TestError;
    } else {
        return;
    }
}

fn returnError(return_error: bool) !void {
    errdefer console.println("errdefer"); // --> `errdefer` only gets executed when
    //                                           this function returns an error.

    try returnErrorInner(return_error); // --> `try` is equal to `someFunc() catch |err| return err;`
    //                                          so if it returns an error, code below here will not be executed.
}

fn UnwrappedType(comptime T: type) type {
    switch (@typeInfo(T)) {
        .@"struct" => |struct_info| {
            var unwrapped_fields: [struct_info.fields.len]type = undefined;
            inline for (struct_info.fields, 0..) |field, i| {
                switch (@typeInfo(field.type)) {
                    .optional => |field_info| {
                        unwrapped_fields[i] = field_info.child;
                    },
                    else => @compileError("all fields must be optional type!"),
                }
            }
            return @Tuple(&unwrapped_fields);
        },
        else => @compileError("parameter must be struct type!"),
    }
}

fn unwrapAll(tuple: anytype) ?UnwrappedType(@TypeOf(tuple)) {
    var result: UnwrappedType(@TypeOf(tuple)) = undefined;
    inline for (tuple, 0..) |opt_field, i| {
        if (opt_field) |field| {
            result[i] = field;
        } else {
            break;
        }
    } else {
        return result;
    }
    return null;
}
