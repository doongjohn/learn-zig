# Learn Zig

## Learning resources

- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [zig.guide](https://zig.guide)
- [Zig Quirks](https://www.openmymind.net/Zig-Quirks/)
- [Build System Tricks](https://ziggit.dev/t/build-system-tricks/)

## Notes

- `zig cc` without generating the `pdb` file.
    - <https://ziggit.dev/t/how-to-use-zig-cc-without-generating-a-pdb-file/2873>

- `zig fetch --save`
    - <https://ziggit.dev/t/feature-or-bug-w-zig-fetch-save/2565/4>

- Include other tests.
    ```zig
    test {
        std.testing.refAllDecls(@This());
        _ = @import("a.zig");
        _ = @import("b.zig");
    }
    ```

- Cross-compile target.
    - `<arch>-<os>-<abi>`
    - `zig build -Dtarget=x86_64-linux-gnu`
    - `zig build -Dtarget=x86_64-windows-gnu`
    - `zig build -Dtarget=x86_64-windows-msvc`

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
