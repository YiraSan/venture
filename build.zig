const std = @import("std");

pub fn build(b: *std.Build) !void {

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const venture = b.addModule("venture", .{
        .root_source_file = b.path("venture/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // sdl3 build static library

    const sdl3 = b.dependency("sdl3", .{});

    {
        const sdl3_build_cmd = switch (target.result.os.tag) {
            .windows => &[_][]const u8 {
                "cmd.exe",
                "/C",
                b.fmt(
                    "cd {s} && cmake -S . -B build -DSDL_STATIC=ON -DSDL_SHARED=OFF -DCMAKE_C_COMPILER=clang && cmake --build build",
                    .{sdl3.path(".").getPath(b)}
                ),
            },
            else => &[_][]const u8 {
                "/bin/sh",
                "-c",
                b.fmt(
                    "cd {s} && cmake -S . -B build -DSDL_STATIC=ON -DSDL_SHARED=OFF -DCMAKE_C_COMPILER=clang && cmake --build build",
                    .{sdl3.path(".").getPath(b)}
                ),
            },
        };
        var child_proc = std.process.Child.init(sdl3_build_cmd, b.allocator);
        child_proc.stdout_behavior = .Ignore;
        try child_proc.spawn();
        const ret_val = try child_proc.wait();
        try std.testing.expectEqual(ret_val, std.process.Child.Term { .Exited = 0 });
    }

    switch (target.result.os.tag) {
        .windows => venture.addObjectFile(sdl3.path("build/SDL3.lib")),
        else => venture.addObjectFile(sdl3.path("build/libSDL3.a")),
    }
    
    venture.addIncludePath(sdl3.path("include/"));

    // vulkan headers version should match latest MoltenVK release and SDL3 supported versions
    const vulkan_headers = b.dependency("vulkan_headers", .{});

    const vkzig_dep = b.dependency("vulkan_zig", .{
        .registry = @as([]const u8, vulkan_headers.path("registry/vk.xml").getPath(b)),
    });
    const vkzig_bindings = vkzig_dep.module("vulkan-zig");
    venture.addImport("vulkan", vkzig_bindings);

    // C Static Library

    const libventure = b.addStaticLibrary(.{
        .name = "venture",
        .root_source_file = b.path("libventure/c.zig"),
        .target = target,
        .optimize = optimize,
    });
    libventure.root_module.addImport("venture", venture);

    const static_step = b.step("static", "build c static library");
    static_step.dependOn(&b.addInstallArtifact(libventure, .{}).step);

    // C Shared Library

    const shared_libventure = b.addSharedLibrary(.{
        .name = "venture",
        .root_source_file = b.path("libventure/c.zig"),
        .target = target,
        .optimize = optimize,
    });
    shared_libventure.root_module.addImport("venture", venture);
    
    const shared_step = b.step("shared", "build c shared library");
    shared_step.dependOn(&b.addInstallArtifact(libventure, .{}).step);

}
