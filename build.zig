const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const root_source_file = b.path("src/main.zig");

    const parg = b.dependency("parg", .{});
    const parg_module = parg.module("parg");

    const exe = b.addExecutable(.{
        .name = "phragen",
        .root_module = b.createModule(.{
            .root_source_file = root_source_file,
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("parg", parg_module);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the application");
    const run_app = b.addRunArtifact(exe);
    run_step.dependOn(&run_app.step);
}
