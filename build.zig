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
    const hello = b.addLibrary(.{
        .name = "hello",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .dynamic,
    });
    hello.addCSourceFiles(.{
        .files = &.{"src/hello.c"},
        .flags = &.{},
    });

    // Link libraries
    exe.linkLibrary(hello);

    // Install artifacts
    b.installArtifact(hello);
    b.installArtifact(exe);

    // Custom build step
    // zig build wow
    const wow_step = b.step("wow", "Custom step");
    wow_step.makeFn = (struct {
        fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) !void {
            _ = step;
            _ = options;
            std.log.info("Running wow step.", .{});
        }
    }).make;

    // Run exe
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&(blk: {
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        run_cmd.addArgs(b.args orelse &.{});
        break :blk run_cmd;
    }).step);

    // Tests
    const exe_unit_tests = b.addRunArtifact(b.addTest(.{
        .root_module = exe_mod,
    }));

    const wow_unit_tests = b.addRunArtifact(b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wow.zig"),
            .target = target,
            .optimize = optimize,
        }),
    }));

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_unit_tests.step);
    test_step.dependOn(&wow_unit_tests.step);
}
