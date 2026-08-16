const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Target: exe
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "learn_zig",
        .root_module = exe_mod,
    });
    exe_mod.addRPathSpecial("$ORIGIN/../lib");

    // Target: hello
    const hello_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    hello_mod.addIncludePath(b.path("hello/internal"));
    hello_mod.addCSourceFiles(.{
        .files = &.{"hello/src/hello.c"},
        .flags = &.{"-DHELLO_SHARED"},
    });

    const hello_lib = b.addLibrary(.{
        .name = "hello",
        .root_module = hello_mod,
        .linkage = .dynamic,
    });
    exe_mod.linkLibrary(hello_lib);

    const hello_c = b.addTranslateC(.{
        .root_source_file = b.path("hello/include/hello/hello.h"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("hello", hello_c.createModule());

    // Install artifacts
    b.installArtifact(exe);
    b.installArtifact(hello_lib);

    // Run step
    const run_step = b.step("run", "Run the app");
    run_step.dependOn((blk: {
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        run_cmd.addPassthruArgs();
        break :blk &run_cmd.step;
    }));

    // Tests
    const exe_tests = b.addRunArtifact(b.addTest(.{
        .root_module = exe_mod,
    }));
    const wow_tests = b.addRunArtifact(b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wow.zig"),
            .target = target,
            .optimize = optimize,
        }),
    }));

    // Test step
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&exe_tests.step);
    test_step.dependOn(&wow_tests.step);
}
