const std = @import("std");
const manifest = @import("build.zig.zon");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const phragen_version: std.SemanticVersion = try .parse(manifest.version);

    const parg = b.dependency("parg", .{});
    const parg_module = parg.module("parg");

    const options = b.addOptions();
    options.addOption(std.SemanticVersion, "version", phragen_version);

    const exe = b.addExecutable(.{
        .name = "phragen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .version = phragen_version,
    });
    exe.root_module.addImport("parg", parg_module);
    exe.root_module.addImport("build_options", options.createModule());

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the application");
    const run_app = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_app.addArgs(args);
    }
    run_step.dependOn(&run_app.step);

    const test_step = b.step("test", "Run tests");
    const test_exe = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .filters = if (b.args) |args| args else &.{},
    });
    test_exe.root_module.addImport("parg", parg_module);

    const run_tests = b.addRunArtifact(test_exe);
    test_step.dependOn(&run_tests.step);

    const release_step = b.step("release", "Build the release binary");

    const target_all = b.option(bool, "target-all", "Build for all supported targets") orelse false;
    const targets: []const std.Target.Query =
        if (target_all) release_targets else &.{target.query};

    for (targets) |t| {
        const release_exe_name = try std.fmt.allocPrint(b.allocator, "phragen-{s}", .{try t.zigTriple(b.allocator)});
        const release_exe = b.addExecutable(.{
            .name = release_exe_name,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = b.resolveTargetQuery(t),
                .optimize = .ReleaseSafe,
            }),
            .version = phragen_version,
        });
        release_exe.root_module.addImport("parg", parg_module);
        release_exe.root_module.addImport("build_options", options.createModule());

        const release_output = b.addInstallArtifact(release_exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = "release",
                },
            },
        });

        release_step.dependOn(&release_output.step);
    }
}

const release_targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .aarch64, .os_tag = .windows },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
};
