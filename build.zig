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

    switch (target.result.os.tag) {
        .windows => {
            const sdl3 = b.dependency("sdl3_mingw", .{});

            venture.addObjectFile(sdl3.path("x86_64-w64-mingw32\\lib\\libSDL3.a"));
            
            const sdl_header = b.addTranslateC(.{
                .root_source_file = sdl3.path("x86_64-w64-mingw32\\include\\SDL3\\SDL.h"),
                .target = target,
                .optimize = optimize,
                .use_clang = true,
            });
            sdl_header.addIncludePath(sdl3.path("x86_64-w64-mingw32\\include"));
            venture.addImport("sdl", sdl_header.createModule());

            const sdl_vulkan_header = b.addTranslateC(.{
                .root_source_file = sdl3.path("x86_64-w64-mingw32\\include\\SDL3\\SDL_vulkan.h"),
                .target = target,
                .optimize = optimize,
                .use_clang = true,
            });
            sdl_vulkan_header.addIncludePath(sdl3.path("x86_64-w64-mingw32\\include"));
            venture.addImport("sdl_vulkan", sdl_vulkan_header.createModule());
        },
        else => {
            const sdl3 = b.dependency("sdl3", .{});

            {
                // zig fmt: off
                const sdl3_build_cmd = &[_][]const u8 {
                    "/bin/sh",
                    "-c",
                    "cmake -S . -B build -DSDL_STATIC=ON -DSDL_SHARED=OFF -DCMAKE_C_COMPILER=clang && cmake --build build",
                };
                // zig fmt: on
                var child_proc = std.process.Child.init(sdl3_build_cmd, b.allocator);
                child_proc.stdout_behavior = .Ignore;
                child_proc.cwd = sdl3.path(".").getPath(b);
                try child_proc.spawn();
                const ret_val = try child_proc.wait();
                try std.testing.expectEqual(ret_val, std.process.Child.Term { .Exited = 0 });
            }

            venture.addObjectFile(sdl3.path("build/libSDL3.a"));
            
            const sdl_header = b.addTranslateC(.{
                .root_source_file = sdl3.path("include/SDL3/SDL.h"),
                .target = target,
                .optimize = optimize,
                .use_clang = true,
            });
            sdl_header.addIncludePath(sdl3.path("include"));
            venture.addImport("sdl", sdl_header.createModule());

            const sdl_vulkan_header = b.addTranslateC(.{
                .root_source_file = sdl3.path("include/SDL3/SDL_vulkan.h"),
                .target = target,
                .optimize = optimize,
                .use_clang = true,
            });
            sdl_vulkan_header.addIncludePath(sdl3.path("include"));
            venture.addImport("sdl_vulkan", sdl_vulkan_header.createModule());
        },
    }

    switch (target.result.os.tag) {
        .windows => {

        },
        .macos => {
            venture.linkFramework("Foundation", .{});
            venture.linkFramework("AVFoundation", .{});
            venture.linkFramework("Carbon", .{});
            venture.linkFramework("Cocoa", .{});
            venture.linkFramework("IOKit", .{});
            venture.linkFramework("QuartzCore", .{});
            venture.linkFramework("Metal", .{});
            venture.linkFramework("GameController", . {});
            venture.linkFramework("CoreServices", .{});
            venture.linkFramework("CoreVideo", .{});
            venture.linkFramework("CoreFoundation", .{});
            venture.linkFramework("CoreAudio", .{});
            venture.linkFramework("CoreMedia", .{});
            venture.linkFramework("CoreHaptics", .{});
            venture.linkFramework("AudioToolbox", .{});
            venture.linkFramework("CoreText", .{});
            venture.linkFramework("CoreGraphics", .{});
            venture.linkFramework("ForceFeedback", .{});
            venture.linkFramework("UniformTypeIdentifiers", .{});
        },
        else => {},
    }

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

    const static_step = b.step("static_lib", "Build C static library.");
    static_step.dependOn(&b.addInstallArtifact(libventure, .{}).step);

    // C Shared Library

    const shared_libventure = b.addSharedLibrary(.{
        .name = "venture",
        .root_source_file = b.path("libventure/c.zig"),
        .target = target,
        .optimize = optimize,
    });
    shared_libventure.root_module.addImport("venture", venture);
    
    const shared_step = b.step("shared_lib", "Build C shared library.");
    shared_step.dependOn(&b.addInstallArtifact(libventure, .{}).step);

}
