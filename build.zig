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
            venture.linkFramework("AppKit", .{});
            venture.linkFramework("MetalKit", .{});
            venture.linkFramework("ForceFeedback", .{});
            venture.linkFramework("UniformTypeIdentifiers", .{});
        },
        else => {},
    }

    // wgpu

    const wgpu = switch (target.result.os.tag) {
        .windows => switch (target.result.cpu.arch) {
            .x86_64 => b.dependency("wgpu_windows_x64", .{}),
            else => @panic("unsupported cpu")
        },
        .macos => switch (target.result.cpu.arch) {
            .x86_64 => b.dependency("wgpu_macos_x64", .{}),
            .aarch64 => b.dependency("wgpu_macos_aarch64", .{}),
            else => @panic("unsupported cpu")
        },
        .linux => switch (target.result.cpu.arch) {
            .x86_64 => b.dependency("wgpu_linux_x64", .{}),
            .aarch64 => b.dependency("wgpu_linux_aarch64", .{}),
            else => @panic("unsupported cpu")
        },
        else => @panic("unsupported os")
    };

    venture.addObjectFile(wgpu.path("lib/libwgpu_native.a"));

    const webgpu_header = b.addTranslateC(.{
        .root_source_file = wgpu.path("include/webgpu/webgpu.h"),
        .target = target,
        .optimize = optimize,
        .use_clang = true,
    });
    webgpu_header.addIncludePath(wgpu.path("include"));
    venture.addImport("webgpu", webgpu_header.createModule());

    const wgpu_header = b.addTranslateC(.{
        .root_source_file = wgpu.path("include/wgpu/wgpu.h"),
        .target = target,
        .optimize = optimize,
        .use_clang = true,
    });
    wgpu_header.addIncludePath(wgpu.path("include"));
    venture.addImport("wgpu", wgpu_header.createModule());

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
