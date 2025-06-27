const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    const exe = b.addExecutable(.{
        .name = "query-engine",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Enable SIMD optimizations (Docker-compatible)
    exe.addCSourceFile(.{ 
        .file = .{ .path = "src/simd.c" }, 
        .flags = &[_][]const u8{
            "-march=x86-64-v2", 
            "-mtune=generic", 
            "-O3",
            "-msse4.2",
            "-mavx2"
        } 
    });
    
    exe.linkLibC();
    exe.strip = optimize == .ReleaseFast;
    
    b.installArtifact(exe);
    
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    const run_step = b.step("run", "Run the query engine");
    run_step.dependOn(&run_cmd.step);
} 