const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const assembler = b.addExecutable(.{
        .name = "casm",
        .root_source_file = b.path("src/binary.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(assembler);
    const run_asm = b.addRunArtifact(assembler);
    run_asm.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_asm.addArgs(args);
    const asm_step = b.step("assemble", "Assemble into binary");
    asm_step.dependOn(&run_asm.step);

    const emulator = b.addExecutable(.{
        .name = "emulator",
        .root_source_file = b.path("src/emulator.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(emulator);
    const emulate = b.addRunArtifact(emulator);
    emulate.step.dependOn(b.getInstallStep());
    if (b.args) |args| emulate.addArgs(args);
    const emulate_step = b.step("emulate", "Emulate a binary");
    emulate_step.dependOn(&emulate.step);

    const main = b.addExecutable(.{
        .name = "cisc64",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(main);
    const main_cmd = b.addRunArtifact(main);
    main_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| main_cmd.addArgs(args);
    const main_step = b.step("run", "Assemble and Emulate");
    main_step.dependOn(&main_cmd.step);


}
