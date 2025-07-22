# Learn Zig

## Learning resources

- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [zig.guide](https://zig.guide)
- [Zig Quirks](https://www.openmymind.net/Zig-Quirks/)

## Build system

- Tutorials
    - [Zig build system](https://ziglang.org/learn/build-system/)
    - [Zig build system basics](https://www.youtube.com/watch?v=jy7w_7JZYyw)
    - [The build cache of Zig](https://alexrios.me/blog/zig-build-cache/)
    - [Build System Tricks](https://ziggit.dev/t/build-system-tricks/)
- Package management
    - `zig fetch --save` <https://ziggit.dev/t/feature-or-bug-w-zig-fetch-save/2565/4>
- Linking with pre-built `dll`.
    ```zig
    const exe = b.addExecutable(.{...});
    exe.addIncludePath(b.path("vendor/SDL3-3.1.6/include"));
    exe.addLibraryPath(b.path("vendor/SDL3-3.1.6_build"));
    exe.linkSystemLibrary("SDL3");
    exe.linkLibC();

    b.installArtifact(exe);

    // Copy the dll to the exe path.
    b.installBinFile("vendor/SDL3-3.1.6_build/SDL3.dll", "SDL3.dll");
    ```

## Cross-compile

- `<arch>-<os>-<abi>`
- `zig build -Dtarget=x86_64-linux-gnu`
- `zig build -Dtarget=x86_64-windows-gnu`
- `zig build -Dtarget=x86_64-windows-msvc`

## Testing

- Include tests from imported files.
    ```zig
    test {
        std.testing.refAllDecls(@This());
        _ = @import("a.zig");
        _ = @import("b.zig");
    }
    ```

## Zig as a C compiler

- `zig cc` without generating the `pdb` file.
    ```sh
    zig cc -s main.c
    ```
