// https://ziglang.org/documentation/master/
// https://www.openmymind.net/Zig-Quirks/

const builtin = @import("builtin");
const native_arch = builtin.cpu.arch;

const std = @import("std");
const mem = std.mem;
const os = std.os;

const Console = struct {
    // cross compile to windows: zig build -Dtarget=x86_64-windows
    // windows console api (easy c interop!)
    const WINAPI: std.builtin.CallingConvention = if (native_arch == .x86) .Stdcall else .C;
    extern "kernel32" fn SetConsoleOutputCP(cp: os.windows.UINT) callconv(WINAPI) bool;
    extern "kernel32" fn ReadConsoleW(handle: os.fd_t, buffer: [*]u16, len: os.windows.DWORD, read: *os.windows.DWORD, input_ctrl: ?*anyopaque) callconv(WINAPI) bool;

    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    const stdin_handle = std.io.getStdIn().handle;

    pub fn init() void {
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

    /// this function uses single global buffer for the input!
    /// please copy the result if you want to keep the result
    pub fn readLine() ![]const u8 {
        switch (builtin.os.tag) {
            .windows => {
                @memset(&input_buf, 0);
                @memset(&input_buf_utf16, 0);

                var readCount: u32 = undefined;
                if (!ReadConsoleW(stdin_handle, &input_buf_utf16, input_max, &readCount, null))
                    return error.ReadConsoleFailed;

                const len = try std.unicode.utf16leToUtf8(&input_buf, input_buf_utf16[0..readCount]);
                //                          ^^^^^^^^^^^^^
                //                          └> windows uses utf16 internally so you need to convert it to utf8 to
                //                             make it friendly for zig std library
                return mem.trimRight(u8, input_buf[0..len], "\r\n");
                //                                           ^^^^ --> trim windows '\r\n'
            },
            else => {
                @memset(&input_buf, 0);

                return try stdin.readUntilDelimiter(&input_buf, '\n');
                //               ^^^^^^^^^^^^^^^^^^
                //               └> Can't read unicode from windows console! (use windows ReadConsoleW api)
            },
        }
    }
};

pub fn h1(comptime text: []const u8) void {
    Console.println("\n\x1b[;92m" ++ "# " ++ text ++ "\x1b[0m");
}

pub fn h2(comptime text: []const u8) void {
    Console.println("\n\x1b[;32m" ++ "## " ++ text ++ "\x1b[0m");
}

pub fn main() !void {
    // init general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok); // detect memory leak
    const galloc = gpa.allocator();

    // use c allocator for valgrind
    // (you also need to link libc to use this)
    // const galloc = std.heap.c_allocator;

    // init terminal io
    Console.init();

    h1("terminal io");
    {
        Console.print(">> terminal input: ");
        const raw_input = try Console.readLine();
        Console.printf("raw_input = {s}\n", std.fmt.fmtSliceEscapeLower(raw_input));

        const trimmed_input = mem.trim(u8, raw_input, "\t ");
        //                                             ^^^ --> trim whitespace
        Console.printf("trimmed_input = {s}\n", .{trimmed_input});
        Console.printf("byte len = {d}\n", .{trimmed_input.len});
        Console.printf("unicode len = {d}\n", .{try std.unicode.utf8CountCodepoints(trimmed_input)});
    }

    h1("variable");
    {
        var n: u8 = 0b0000_0_1_01;
        //          ^^^^^^^^^^^^^ --> "_" can be used anywhere in a
        //                            numeric literal for better readability
        Console.printf("{d}\n", .{n});

        const imm = 10;
        // imm = 100; // <-- error: cannot assign to constant
        Console.printf("{d}\n", .{imm});
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
        Console.println(some_text);
    }

    h1("loop");
    {
        h2("while loop");
        var i: i64 = 0;

        i = 0;
        while (i < 5) {
            defer i += 1;
            Console.printf("{d} ", .{i});
        }
        Console.printf("while end: i = {d}\n", .{i});
        Console.println("");

        i = 0;
        while (i < 5) : (i += 1) {
            Console.printf("{d} ", .{i});
        }
        Console.printf("while end: i = {d}\n", .{i});
        Console.println("");

        i = 0;
        while (i < 5) : ({
            Console.print("(while : ())\n");
            i += 1;
        }) {
            defer Console.print("(defer) ");
            Console.printf("while body: {d} ", .{i});
        }
        Console.printf("while end: i = {d}\n", .{i});
    }
    {
        h2("for loop");
        const string = "Hello world!";

        // range
        for (0..5) |i| { // 0 ~ 4
            Console.printf("{} ", .{i});
        }
        Console.println("");

        // get element
        for (string) |byte| {
            Console.printf("{c} ", .{byte});
        }
        Console.println("");

        // get index
        for (string, 0..) |_, index| {
            Console.printf("{d} ", .{index});
        }
        Console.println("");

        // get element and index
        for (string, 0..) |byte, index| {
            Console.printf("string[{d}]: {c}\n", .{ index, byte });
        }

        // multi-object for loop
        var arr1 = [_]i32{ 1, 2, 3, 4, 5, 6 };
        var arr2 = [_]i32{ 2, 3, 4, 5, 6, 7, 8 };
        var arr3 = [_]i32{ 2, 3, 4, 5, 6, 7, 8, 9 };

        for (arr1, arr2[0..6], arr3[0..6]) |item1, item2, item3| {
            Console.printf("arr1: {d}, arr2: {d} arr3: {d}\n", .{ item1, item2, item3 });
        }
    }
    {
        h2("for else");

        const string1 = "hello world";
        Console.printf("find w in {s}\n", .{string1});
        const w1 = for (string1) |byte| {
            if (byte == 'w') {
                break byte;
            }
        } else blk: {
            // this runs when a for loop didn't break
            break :blk 'x';
        };
        Console.printf("found: {c}\n", .{w1});

        const string2 = "hello";
        Console.printf("find w in {s}\n", .{string2});
        Console.println("if not found return \'x\'");
        const w2 = for (string2) |byte| {
            if (byte == 'w') {
                break byte;
            }
        } else blk: {
            // this runs when a for loop didn't break
            break :blk 'x';
        };
        Console.printf("found: {c}\n", .{w2});
    }

    h1("pointer");
    {
        h2("basic pointer");
        var num: i32 = 10;
        Console.printf("num: {d}\n", .{num});

        var num_ptr: *i32 = undefined;
        //           ^^^^ --> pointer type
        num_ptr = &num;
        //        ^^^^ --> pointer of variable num (just like c)
        num_ptr.* += 5;
        //     ^^ --> dereference pointer

        Console.printf("num: {d}\n", .{num});
    }
    {
        h2("immutable dereference");
        var num: i32 = 20;
        var ptr: *const i32 = &num;
        //       ^^^^^^ --> immutable dereference
        //                  ptr.* = 1; <-- this is compile time error
        Console.printf("num: {d}\n", .{ptr.*});
    }
    {
        h2("heap allocation");
        const heap_int = try galloc.create(i32);
        //                          ^^^^^^ --> allocates a single item
        defer galloc.destroy(heap_int);
        //           ^^^^^^^ --> deallocates a single item

        heap_int.* = 100;
        Console.printf("num: {d}\n", .{heap_int.*});
    }
    {
        h2("optional(nullable) pointer");
        var opt_ptr: ?*i32 = null;
        //           ^ --> optional type (null is allowed)
        //                 it is zero cost for the pointer

        opt_ptr = try galloc.create(i32);
        defer if (opt_ptr) |ptr| galloc.destroy(ptr);

        opt_ptr.?.* = 100;
        //     ^^ --> unwraps optional (runtime error if null)
        Console.printf("optional pointer value: {d}\n", .{opt_ptr.?.*});

        if (opt_ptr) |ptr| {
            //        ^^^ --> this is unwrapped ptr and this variable is
            //                only available in this scope
            ptr.* = 10;
            Console.printf("optional pointer value: {d}\n", .{ptr.*});
        } else {
            Console.println("optional pointer value: null");
        }

        blk: {
            var ptr = opt_ptr orelse break :blk;
            //                ^^^^^^ --> it returns unwrapped valur if the value is not null
            //                           https://ziglang.org/documentation/master/#Optionals
            ptr.* += 10;
            Console.printf("optional pointer value: {d}\n", .{ptr.*});
        }
    }

    h1("function pointer & alias");
    {
        // function pointer
        const f: *const fn () void = haha;
        f();
        Console.printf("{s}\n", .{@typeName(@TypeOf(f))});

        // function alias
        const f2: fn () void = haha;
        f2();
        Console.printf("{s}\n", .{@typeName(@TypeOf(f2))});
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
            Console.printf("[{d}]: {d}\n", .{ i, item.* });
        }

        h2("init array with ** operator");
        const array2 = [_]i64{ 1, 2, 3 } ** 3;
        //                   ^^^^^^^^^^^^^ --> this will create: { 1, 2, 3, 1, 2, 3, 1, 2, 3 }
        //                                     at compile time
        Console.printf("{any}\n", .{array2});

        h2("assigning array to array");
        // array gets copied when assigned
        var arr1 = [_]i32{ 0, 0, 0 };
        var arr2 = arr1;
        Console.printf("arr1: {p}\n", .{&arr1[0]});
        Console.printf("arr2: {p}\n", .{&arr2[0]});

        h2("concat array compile-time");
        const concated = "wow " ++ "hey " ++ "yay";
        //                      ^^ --> compiletime array concatenation operator
        Console.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });

        h2("slice");
        var arr1_slice = arr1[0..]; // a slice is a pointer and a length (its length is known at runtime)
        //                    ^^^
        //                    └> from index 0 to the end
        Console.printf("arr1: {p}\n", .{&arr1[0]});
        Console.printf("arr1_slice: {p}\n", .{&arr1_slice[0]});
        arr1_slice[0] = 10;
        for (arr1_slice, 0..) |item, i| {
            Console.printf("[{d}]: {d}\n", .{ i, item });
        }
        Console.printf("arr[0]: {d}\n", .{&arr1[0]});

        arr1_slice = &arr1;
        //           ^^^^^
        //           └> array pointer can be coerced to slice

        h2("pointer to array");
        const arr_ptr = &array; // pointer to an array
        Console.printf("{s}\n", .{@typeName(@TypeOf(array))});
        Console.printf("{s}\n", .{@typeName(@TypeOf(arr_ptr))});
        for (arr_ptr, 0..) |item, i| {
            Console.printf("[{d}]: {d}\n", .{ i, item });
        }

        h2("@memset");
        @memset(&array, 3); // --> set every elements in array to 3
        for (array, 0..) |item, i| {
            Console.printf("[{d}]: {d}\n", .{ i, item });
        }
    }
    {
        h2("strings");

        // strings are just u8 array
        // (so handling Unicode is not trivial...)
        var yay = [_]u8{ 'y', 'a', 'y' };
        yay[0] = 'Y';
        Console.println(yay[0..]);
        Console.printf("{s}\n", .{@typeName(@TypeOf(yay))});

        // string literals are const slice to null terminated u8 array
        // read more: https://zig.news/kristoff/what-s-a-string-literal-in-zig-31e9
        // read more: https://zig.news/david_vanderson/beginner-s-notes-on-slices-arrays-strings-5b67
        var str_lit = "this is a string literal";
        Console.printf("{s}\n", .{@typeName(@TypeOf(str_lit))});
        // (&str_lit[0]).* = 'A'; // <-- this is compile error because it's a const slice
        //                               very nice!

        // multiline string
        const msg =
            \\Hello, world!
            \\Zig is awesome!
            \\
        ;
        Console.print(msg);
    }
    {
        h2("heap allocated array");
        Console.print(">> array length: ");
        var array_length: usize = undefined;
        while (true) {
            const input = try Console.readLine();
            // handle error
            array_length = std.fmt.parseInt(usize, input, 10) catch {
                Console.print(">> please input positive number: ");
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
        Console.printf("{any}\n", .{array});

        h2("concat array run-time");
        const words = [_][]const u8{ "wow ", "hey ", "yay" };
        const concated = try mem.concat(galloc, u8, words[0..]);
        defer galloc.free(concated);
        Console.printf("concated: {s}\nlength: {d}\n", .{ concated, concated.len });

        h2("std.ArrayList");
        // string builder like function with ArrayList
        var str_builder = std.ArrayList(u8).init(galloc);
        defer str_builder.deinit();
        try str_builder.appendSlice("wow ");
        try str_builder.appendSlice("this is cool! ");
        try str_builder.appendSlice("super power!");
        Console.printf("{s}\n", .{str_builder.items});
    }

    h1("enum");
    {
        const MyEnum = enum(u8) { Hello, Bye, _ };
        //                                    ^ --> non-exhaustive enum
        //                                          must use `else` in the switch

        var e: MyEnum = .Hello;
        switch (e) {
            .Hello => Console.printf("{}\n", .{e}),
            .Bye => Console.printf("{}\n", .{e}),
            else => Console.println("other"),
        }
    }

    h1("struct");
    {
        // all types including struct is a value that can be stored in a comptime variable
        // https://ziglang.org/documentation/master/#Struct-Naming
        const SomeStruct = struct {
            num: i64 = 0, // <-- this field has a default value
            text: []const u8,
        };

        var some_struct = SomeStruct{ .text = "" }; // initalize struct by `StructName{}`
        //                            ^^^^^^^^^^
        //                            └-> this is necessary because `text` has no default value
        some_struct.num = 10;
        some_struct.text = "hello";
        Console.printf("some_struct = {}\n", .{some_struct});
        Console.printf("some_struct.text = {s}\n", .{some_struct.text});

        var point: Point2d() = undefined;
        //         ^^^^^^^^^
        //         └-> function returning a type can be used as a type
        point = Point2d(){ .x = 10, .y = 20 };
        Console.printf("point = {}\n", .{point});

        // result location semantics
        // https://www.youtube.com/watch?v=dEIsJPpCZYg
        var s: struct { a: i32, b: i32 } = .{
            .a = 10,
            .b = 20,
        };
        Console.printf("s: {}\n", .{s});
        s = .{
            .a = 50, // <-- writes 50 to s.a
            .b = s.a, // <-- writes s.a to s.b so it becomes 50
        };
        Console.printf("s: {}\n", .{s});

        h2("tuple");
        // struct without field name can be used as a tuple
        // https://ziglang.org/documentation/master/#Tuples
        var tuple = .{ @as(i32, 100), "yo" };
        Console.printf("{d}\n", .{tuple[0]});
        Console.printf("{s}\n", .{tuple[1]});

        // structs can be combined at compiletime
        var tuple2 = tuple ++ .{"wow"};
        Console.printf("{d}\n", .{tuple2[0]});
        Console.printf("{s}\n", .{tuple2[1]});
        Console.printf("{s}\n", .{tuple2[2]});
    }

    h1("destructuring");
    {
        // destructuring can be done with
        // * Tuples
        // * Arrays
        // * Vectors

        var tuple = .{ @as(i32, 10), "hello" };
        Console.printf("{s}\n", .{@typeName(@TypeOf(tuple))});
        var num, var str = tuple;
        Console.printf("num = {d}\n", .{num});
        Console.printf("str = {s}\n", .{str});

        var arr = [_]i32{ 1, 2, 3, 4 };
        var n1, var n2, _, _ = arr;
        Console.printf("n1 = {d}\n", .{n1});
        Console.printf("n2 = {d}\n", .{n2});
    }

    h1("error & errdefer");
    {
        h2("with error");
        returnError(true) catch |err| {
            Console.printf("{!}\n", .{err});
        };

        h2("without error");
        returnError(false) catch |err| {
            Console.printf("{!}\n", .{err});
        };
    }

    h1("refiy type");
    {
        // type can be created at compile-time
        // https://github.com/ziglang/zig/blob/61b70778bdf975957d45432987dde16029aca69a/lib/std/builtin.zig#L228
        const MyInt = @Type(.{ .Int = .{
            .signedness = .signed,
            .bits = 32,
        } });

        var n: MyInt = 20;
        Console.printf("{d}\n", .{n});

        // multiple unwrap using refiy type
        var opt_a: ?i32 = null;
        var opt_b: ?f32 = 2.2;
        if (unwrapAll(.{ opt_a, opt_b })) |unwrapped| {
            var a, var b = unwrapped;
            Console.println("unwrap success");
            Console.printf("a = {}, b = {}\n", .{ a, b });
        } else {
            Console.println("unwrap failed");
        }

        opt_a = 10;
        if (unwrapAll(.{ opt_a, opt_b })) |unwrapped| {
            var a, var b = unwrapped;
            Console.println("unwrap success");
            Console.printf("a = {}, b = {}\n", .{ a, b });
        } else {
            Console.println("unwrap failed");
        }
    }

    h1("lambda");
    {
        const TestLambda = struct {
            data: i32,

            fn func(self: @This()) void {
                Console.printf("this is lambda, data = {d}\n", .{self.data});
            }
        };

        const a = 100;
        testLambdaCaller(TestLambda{ .data = a });
    }

    h1("random");
    {
        // init random number generator
        const seed = @as(u64, @intCast(std.time.timestamp()));
        var rng_impl = std.rand.DefaultPrng.init(seed);
        const random = rng_impl.random();

        for (0..3) |_| {
            const random_num = random.intRangeAtMost(i64, 1, 10); // generate random value
            Console.printf("random between 1 ~ 10 => {}\n", .{random_num});
        }
    }
}

fn haha() void {
    std.debug.print("haha\n", .{});
}

fn UnwrappedType(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Struct => |struct_info| {
            var unwrapped_fields: [struct_info.fields.len]std.builtin.Type.StructField = undefined;
            inline for (struct_info.fields, 0..) |field, i| {
                switch (@typeInfo(field.type)) {
                    .Optional => |field_info| {
                        unwrapped_fields[i] = .{
                            .name = field.name,
                            .type = field_info.child,
                            .default_value = field.default_value,
                            .is_comptime = field.is_comptime,
                            .alignment = 0, // meaningless for `.layout = .Auto`
                        };
                    },
                    else => @compileError("all fields must be optional type!"),
                }
            }

            return @Type(.{
                .Struct = .{
                    .layout = .Auto,
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

// name of a function that returns a type should start with a capital letter
fn Point2d() type {
    return struct {
        x: i64 = 0,
        y: i64 = 0,
    };
}

fn testLambdaCaller(lambda: anytype) void {
    if (@TypeOf(@TypeOf(lambda).func) != fn (self: @TypeOf(lambda)) void)
        @compileError("lambda must have a function `fn func(self)`");

    lambda.func();
}

fn returnErrorInner(return_error: bool) !void {
    // const Error = error{TestError}; // --> error set
    //                                        https://ziglang.org/documentation/master/#Errors
    if (return_error) {
        return error.TestError;
    } else {
        return;
    }
}

fn returnError(return_error: bool) !void {
    errdefer Console.println("errdefer");
    try returnErrorInner(return_error); // --> `try` is equal to `someFunc() catch |err| return err;`
    //                                          so if it returns an error, code below here will not be executed
}
