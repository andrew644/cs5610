const std = @import("std");
const this = @This();
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "cs_5610",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    //GLAD
    const glad = b.addStaticLibrary(.{
        .name = "glad",
        .target = target,
        .optimize = optimize,
    });
    glad.linkLibC();
    const glad_dep = b.dependency("glad", .{});
    glad.addCSourceFile(.{ .file = b.path("lib/glad/src/glad.c") });
    glad.addIncludePath(b.path("lib/glad"));
    exe.addIncludePath(glad_dep.path("."));
    b.installArtifact(glad);
    exe.linkLibrary(glad);

    exe.linkLibC();
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("gl");
    exe.linkSystemLibrary("assimp");
    exe.linkSystemLibrary("cglm");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
