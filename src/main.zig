const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const os = std.os;
const fs = std.fs;

// Cross-compiling to Windows:
// zig build -Dtarget=x86_64-windows
const win32 = if (builtin.os.tag == .windows) struct {
    const win = std.os.windows;

    // Windows API (Easy C interop!)
    extern "kernel32" fn ReadConsoleW(handle: win.HANDLE, buffer: [*]u16, len: win.DWORD, read: *win.DWORD, input_ctrl: ?*anyopaque) callconv(.winapi) bool;
};

const console = struct {
    var stdout: fs.File.Writer = undefined;
    var stdin: fs.File.Reader = undefined;
    var stdin_handle: fs.File.Handle = undefined;

    var orig_outputcp: if (builtin.os.tag == .windows)
        os.windows.UINT = undefined;

    pub fn init() void {
        stdout = std.io.getStdOut().writer();
        stdin = std.io.getStdIn().reader();
        stdin_handle = std.io.getStdIn().handle;

        if (builtin.os.tag == .windows) {
            orig_outputcp = os.windows.kernel32.GetConsoleOutputCP();
            _ = os.windows.kernel32.SetConsoleOutputCP(65001); // UTF8
        }
    }

    pub fn deinit() void {
        if (builtin.os.tag == .windows) {
            _ = os.windows.kernel32.SetConsoleOutputCP(orig_outputcp);
        }
    }

    pub fn print(str: []const u8) void {
        _ = stdout.write(str) catch |err| std.debug.panic("stdout.write error: {!}", .{err});
    }

    pub fn println(str: []const u8) void {
        _ = stdout.write(str) catch |err| std.debug.panic("stdout.write error: {!}", .{err});
        _ = stdout.writeByte('\n') catch |err| std.debug.panic("stdout.writeByte error: {!}", .{err});
    }

    pub fn printf(comptime format: []const u8, args: anytype) void {
        stdout.print(format, args) catch |err| std.debug.panic("stdout.print error: {!}", .{err});
    }

    const line_buf_size = 10000;
    var utf8_line_buf: [line_buf_size]u8 = .{0} ** line_buf_size;
    var utf16_line_buf: [line_buf_size]u16 = .{0} ** line_buf_size;

    /// This function uses one buffer for storing the input string.
    /// You need to copy it if you want to keep the string reference.
    pub fn readLine() ![]const u8 {
        switch (builtin.os.tag) {
            .windows => {
                var utf16_read_count: u32 = undefined;
                if (!win32.ReadConsoleW(stdin_handle, &utf16_line_buf, line_buf_size, &utf16_read_count, null))
                    return error.ReadConsoleError;

                const utf8_len = try std.unicode.utf16LeToUtf8(&utf8_line_buf, utf16_line_buf[0..utf16_read_count]);
                //                               ^^^^^^^^^^^^^
                //                               └> Windows uses utf16 so you need to convert it to utf8 to
                //                                  make it friendly for zig std library.
                return mem.trimRight(u8, utf8_line_buf[0..utf8_len], "\r\n");
                //                                                    ^^^^ --> Trim windows '\r\n'.
            },
            else => {
                return mem.trimRight(u8, try stdin.readUntilDelimiter(&utf8_line_buf, '\n'), "\n");
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

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    // Init general purpose allocator
    const alloc, const is_debug = gpa: {
        if (builtin.os.tag == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        std.debug.assert(debug_allocator.deinit() == .ok);
        //                              ^^^^^^^^^^^^^^^^ --> Detect memory leak.
    };

    // You need to use a `c_allocator` for valgrind. (You need to link LibC.)
    // const alloc = std.heap.c_allocator;

    console.init();
    defer console.deinit();

    h1("terminal io");
    {
        console.print(">> terminal input: ");
        const input = mem.trim(u8, try console.readLine(), " \t");
        //                                                  ^^^ --> trim whitespace
        console.printf("input = {s}\n", .{input});
        console.printf("byte length = {d}\n", .{input.len});
        console.printf("unicode length = {d}\n", .{try std.unicode.utf8CountCodepoints(input)});
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
    }

    h1("function pointer & alias");
    {
        // function pointer
        const f: *const fn () void = haha;
        f();
        console.printf("{s}\n", .{@typeName(@TypeOf(f))});

        // function alias
        const f2: fn () void = haha;
        f2();
        console.printf("{s}\n", .{@typeName(@TypeOf(f2))});

        // nested function
        const nested_fn = struct {
            fn func() void {
                console.println("nested fn");
            }
        };
        nested_fn.func();
    }

    h1("array");
    {
        h2("basic array");
        var array = [_]i64{ 1, 10, 100 }; // This array is mutable because it is declared as `var`.
        //          ^^^ --> Same as [3]i64 because it has 3 items. (zig can infer the length.)
        for (&array, 0..) |*item, i| {
            //             ^^^^^  ^
            //             |      └> Current index. (usize)
            //             └> Capture the element as a pointer. (So that we can change its value.)
            item.* = @intCast(i + 1);
            console.printf("[{d}]: {d}\n", .{ i, item.* });
        }

        h2("init array with ** operator");
        const array2 = [_]i64{ 1, 2, 3 } ** 3;
        //                   ^^^^^^^^^^^^^ --> This will create: { 1, 2, 3, 1, 2, 3, 1, 2, 3 } at compile-time.
        console.printf("{any}\n", .{array2});

        h2("assigning array to array");
        var arr1 = [_]i32{ 0, 0, 0 };
        var arr2 = arr1; // Array gets copied when assigned.
        console.printf("arr1: {p}\n", .{&arr1[0]});
        console.printf("arr2: {p}\n", .{&arr2[0]});

        h2("concat array compile-time");
        const concated = "wow " ++ "hey " ++ "yay";
        //                      ^^ --> Compile-time array concatenation operator.
        console.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });

        h2("slice");
        var arr1_slice = arr1[0..]; // Slice is a pointer and a length. (Its length is known at runtime.)
        //                    ^^^
        //                    └> From index 0 to the end.
        console.printf("arr1: {p}\n", .{&arr1[0]});
        console.printf("arr1_slice: {p}\n", .{&arr1_slice[0]});
        arr1_slice[0] = 10;
        for (arr1_slice, 0..) |item, i| {
            console.printf("[{d}]: {d}\n", .{ i, item });
        }
        console.printf("arr[0]: {d}\n", .{&arr1[0]});

        arr1_slice = &arr1;
        //           ^^^^^
        //           └> Array pointer can be coerced to slice.

        h2("pointer to array");
        const arr_ptr = &array; // Pointer to an array.
        console.printf("{s}\n", .{@typeName(@TypeOf(array))});
        console.printf("{s}\n", .{@typeName(@TypeOf(arr_ptr))});
        for (arr_ptr, 0..) |item, i| {
            console.printf("[{d}]: {d}\n", .{ i, item });
        }

        h2("@memset");
        @memset(&array, 3); // --> Set every elements in the array to 3.
        for (array, 0..) |item, i| {
            console.printf("[{d}]: {d}\n", .{ i, item });
        }
    }
    {
        h2("strings");

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
    {
        h2("heap allocated array");
        console.print(">> array length: ");
        var array_length: usize = undefined;
        while (true) {
            const input = try console.readLine();
            array_length = std.fmt.parseInt(usize, input, 10) catch {
                //                                            ^^^^^ --> Handle the error.
                console.print(">> please input positive number: ");
                continue;
            };
            break;
        }

        const array = try alloc.alloc(i64, array_length);
        //                       ^^^^^ --> Allocate an array.
        defer alloc.free(array);
        //           ^^^^ --> Deallocate an array.
        for (array, 0..) |*item, i| {
            item.* = @intCast(i);
        }
        console.printf("{any}\n", .{array});

        h2("concat array run-time");
        const words = [_][]const u8{ "wow ", "hey ", "yay" };
        const concated = try mem.concat(alloc, u8, words[0..]);
        defer alloc.free(concated);
        console.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });

        h2("std.ArrayList");
        // You can use `ArrayList(u8)` as String builder.
        var str_builder = std.ArrayList(u8).init(alloc);
        defer str_builder.deinit();
        try str_builder.appendSlice("wow ");
        try str_builder.appendSlice("this is cool! ");
        try str_builder.appendSlice("super power!");
        console.printf("{s}\n", .{str_builder.items});
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

        var some_struct = SomeStruct{ .text = "" }; // Initalize struct by `StructName{}`.
        //                            ^^^^^^^^^^
        //                            └-> This is necessary because `text` has no default value.
        some_struct.num = 10;
        some_struct.text = "hello";
        console.printf("some_struct = {}\n", .{some_struct});
        console.printf("some_struct.text = {s}\n", .{some_struct.text});

        var point: Point2d() = undefined;
        //         ^^^^^^^^^
        //         └-> Function returning a type can be used as a type.
        point = Point2d(){ .x = 10, .y = 20 };
        console.printf("point = {}\n", .{point});

        // Result location semantics.
        // https://www.youtube.com/watch?v=dEIsJPpCZYg
        var s: struct { a: i32, b: i32 } = .{
            .a = 10,
            .b = 20,
        };
        console.printf("s: {}\n", .{s});
        s = .{
            .a = 50, // <-- Writes 50 to `s.a`.
            .b = s.a, // <-- Writes `s.a` to `s.b` so it becomes 50.
        };
        console.printf("s: {}\n", .{s});

        h2("tuple");
        // Struct without field names can be used as a tuple.
        // https://ziglang.org/documentation/master/#Tuples
        const tuple = .{ @as(i32, 100), "yo" };
        console.printf("{d}\n", .{tuple[0]});
        console.printf("{s}\n", .{tuple[1]});

        // Structs can be combined at compile-time.
        const tuple2 = tuple ++ .{"wow"};
        console.printf("{d}\n", .{tuple2[0]});
        console.printf("{s}\n", .{tuple2[1]});
        console.printf("{s}\n", .{tuple2[2]});
    }

    h1("destructuring");
    {
        // Destructuring can be done with:
        // * Tuples
        // * Arrays
        // * Vectors

        const tuple = .{ @as(i32, 10), "hello" };
        console.printf("{s}\n", .{@typeName(@TypeOf(tuple))});
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
        h2("with error");
        returnError(true) catch |err| {
            console.printf("{!}\n", .{err});
        };

        h2("without error");
        returnError(false) catch |err| {
            console.printf("{!}\n", .{err});
        };
    }

    h1("refiy type");
    {
        // Type can be created at compile-time.
        // https://github.com/ziglang/zig/blob/master/lib/std/builtin.zig#L259
        const MyInt = @Type(.{ .int = .{
            .signedness = .signed,
            .bits = 32,
        } });

        const n: MyInt = 20;
        console.printf("{d}\n", .{n});

        // Multiple unwrap using refiy type.
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

    h1("closure with capture");
    {
        var a: i32 = 100;

        runClosure(struct {
            a: *i32,

            fn call(closure: @This()) void {
                console.printf("this is a closure: a = {d}\n", .{closure.a.*});
                closure.a.* += 100;
                console.printf("this is a closure: a = {d}\n", .{closure.a.*});
            }
        }{
            .a = &a, // capture
        });

        console.printf("a = {d}\n", .{a});
    }

    h1("random");
    {
        const seed: u64 = @intCast(std.time.timestamp());
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

fn UnwrappedType(comptime T: type) type {
    const StructField = std.builtin.Type.StructField;
    switch (@typeInfo(T)) {
        .@"struct" => |struct_info| {
            var unwrapped_fields: [struct_info.fields.len]StructField = undefined;
            inline for (struct_info.fields, 0..) |field, i| {
                switch (@typeInfo(field.type)) {
                    .optional => |field_info| {
                        unwrapped_fields[i] = .{
                            .name = field.name,
                            .type = field_info.child,
                            .default_value_ptr = null,
                            .is_comptime = false,
                            .alignment = 0, // Meaningless for `.layout = .auto`.
                        };
                    },
                    else => @compileError("all fields must be optional type!"),
                }
            }
            return @Type(.{
                .@"struct" = .{
                    .layout = .auto,
                    .fields = &unwrapped_fields,
                    .decls = &.{},
                    .is_tuple = true,
                },
            });
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
