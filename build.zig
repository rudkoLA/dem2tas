const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dem2tas",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const artifacts_step = b.step("artifacts", "Build artifacts for Windows, Linux, and macOS inside ./artifacts/");

    const update_artifacts = b.addUpdateSourceFiles();
    artifacts_step.dependOn(&update_artifacts.step);

    const TargetConfig = struct {
        query: std.Target.Query,
        name: []const u8,
        ext: []const u8 = "",
    };

    const artifact_targets = [_]TargetConfig{
        .{
            .query = .{ .cpu_arch = .x86_64, .os_tag = .windows },
            .name = "dem2tas-x86_64-windows",
            .ext = ".exe",
        },
        .{
            .query = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
            .name = "dem2tas-x86_64-linux",
        },
        .{
            .query = .{ .cpu_arch = .aarch64, .os_tag = .macos },
            .name = "dem2tas-aarch64-macos",
        },
    };

    for (artifact_targets) |t| {
        const resolved_target = b.resolveTargetQuery(t.query);
        const target_exe = b.addExecutable(.{
            .name = t.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = resolved_target,
                .optimize = .ReleaseSmall,
            }),
        });

        const dest_path = b.fmt("artifacts/{s}{s}", .{ t.name, t.ext });
        update_artifacts.addCopyFileToSource(target_exe.getEmittedBin(), dest_path);
    }
}
