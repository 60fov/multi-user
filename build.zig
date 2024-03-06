const std = @import("std");
const Build = std.Build;

// TODO why don't i have to link libc and opengl32.dll
pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // modules
    // const softsrv_module = b.addModule("softsrv", .{
    //     .root_source_file = .{ .path = "lib/softsrv/src/softsrv.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });

    const gl_module = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.6",
        .profile = .core,
        .extensions = &.{},
    });

    const mu_module = b.addModule("multi-user", .{
        .root_source_file = .{ .path = "src/_export.zig" },
        .target = target,
        .optimize = optimize,
    });
    mu_module.addImport("gl", gl_module);

    const exe = b.addExecutable(.{
        .name = "multi-user",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // exe.root_module.addImport("softsrv", softsrv_module);
    exe.root_module.addImport("gl", gl_module);
    exe.linkLibC(); // TODO remove
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "run multi-user");
    run_step.dependOn(&run_cmd.step);

    // playground
    var dir = try std.fs.cwd().openDir("playground/", .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();

    try dir.setAsCwd();

    while (try iter.next()) |entry| {
        switch (entry.kind) {
            .file => {
                const name = std.fs.path.stem(entry.name);
                const pg_exe = b.addExecutable(.{
                    .name = name,
                    .root_source_file = .{ .cwd_relative = entry.name },
                    .target = target,
                    .optimize = optimize,
                    // .link_libc = true,
                });
                pg_exe.root_module.addImport("multi-user", mu_module);

                const pg_install = b.addInstallArtifact(pg_exe, .{});
                const pg_run = b.addRunArtifact(pg_exe);
                const pg_step = b.step(name, "install & run playground file");
                pg_run.step.dependOn(&pg_install.step);
                pg_step.dependOn(&pg_run.step);
            },
            else => continue,
        }
    }
}
