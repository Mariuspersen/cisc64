const std = @import("std");
const CPU = @import("cpu.zig");

const Allocator = std.mem.Allocator;
const Instruction = CPU.Instruction;
const Self = @This();

AL: std.ArrayList(u8),

pub fn init(allocator: Allocator) Self {
    return .{
        .AL = std.ArrayList(u8).init(allocator)
    };
}

pub fn movv(self: *Self, addr: u8, val: u64) !void {
    const writer = self.AL.writer();
    const info = @typeInfo(Instruction);
    try writer.writeInt(info.Enum.tag_type, @intFromEnum(Instruction.MOVV), CPU.Endian);
    try writer.writeByte(addr);
    try writer.writeInt(@TypeOf(val), val, CPU.Endian);
}

pub fn movr(self: *Self, dest: u8, src: u8) !void {
    const info = @typeInfo(Instruction);
    const writer = self.AL.writer();
    try writer.writeInt(info.Enum.tag_type, @intFromEnum(Instruction.MOVR), CPU.Endian);
    try writer.writeByte(dest);
    try writer.writeByte(src);    
}