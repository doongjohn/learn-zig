# Learn Zig

## Learning resources

- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [zig.guide](https://zig.guide)
- [Zig Quirks](https://www.openmymind.net/Zig-Quirks/)
- [Build System Tricks](https://ziggit.dev/t/build-system-tricks/)

## Notes

- `usingnamespace`
    - <https://ziglang.org/documentation/master/#usingnamespace>

- C optimization levels when using `build.zig` to build a C source file
    - <https://ziggit.dev/t/c-optimization-levels/140>

- `zig cc` without generating the pdb
    - <https://ziggit.dev/t/how-to-use-zig-cc-without-generating-a-pdb-file/2873>

- `zig fetch --save`
    - <https://ziggit.dev/t/feature-or-bug-w-zig-fetch-save/2565/4>

- Linking with pre-built `dll`
    - Copy `dll` next to `exe`
        ```zig
        const exe = b.addExecutable(.{...});
        exe.addIncludePath(b.path("vendor/SDL3-3.1.6/include"));
        exe.addLibraryPath(b.path("vendor/SDL3-3.1.6_build"));
        exe.linkSystemLibrary("SDL3");
        exe.linkLibC();

        b.installArtifact(exe);
        b.installBinFile("vendor/SDL3-3.1.6_build/SDL3.dll", "SDL3.dll");  // copy the dll to the exe path
        ```
    - Append `dll` dir to the `PATH`
        ```zig
        const exe = b.addExecutable(.{...});
        exe.addIncludePath(b.path("vendor/SDL3-3.1.6/include"));
        exe.addLibraryPath(b.path("vendor/SDL3-3.1.6_build"));
        exe.linkSystemLibrary("SDL3");
        exe.linkLibC();

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        run_cmd.addPathDir("vendor/SDL3-3.1.6_build"); // `addPathDir` adds a to the `PATH` environment variable.
                                                       // This is to avoid having to copy the dll to the exe path.
        ```
