const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "multi-user",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // const softsrv_module = b.addModule("softsrv", .{
    //     .root_source_file = "lib/softsrv/src/main.zig",
    //     .target = target,
    //     .optimize = optimize,
    // });

    // exe.root_module.addImport("softsrv", softsrv_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "run multi-user");
    run_step.dependOn(&run_cmd.step);
}
