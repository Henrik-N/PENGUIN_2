const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    b.prominent_compile_errors = true;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "PENGUIN",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the executable to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running 'zig build')
    exe.install();

    // C
    exe.linkLibC();
    // X11 libs
    {
        exe.linkSystemLibrary("xcb");
        exe.linkSystemLibrary("X11");
        exe.linkSystemLibrary("X11-xcb");
        exe.linkSystemLibrary("xkbcommon");
    }

    // Run step
    {
        // This *creates* a RunStep in the build graph, to be executed when another
        // step is evaluated that depends on it. The line below will establish
        // such a dependency.
        const run_cmd = exe.run();

        // Run from installation directory rather than cache directory.
        run_cmd.step.dependOn(b.getInstallStep());

        // This allows the user to pass arguments to the application in the build command
        // itself, like this: zig build run -- arg1 arg2 etc
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    // Unit testing step
    {
        const exe_tests = b.addTest(.{
            .root_source_file = .{ .path = "src/main.zig" },
            .target = target,
            .optimize = optimize,
        });
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&exe_tests.step);
    }
}
