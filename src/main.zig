const std = @import("std");
const CPU = @import("cpu.zig");
const assembler = @import("assembler.zig");

const program = [_]u8{
    0x01,
    0x0A,
    0x00,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0x02,
    0x02,
    0x01,
    0x00,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var a = assembler.init(allocator);
    try a.movv(0, 0xFFFFFFFFFFFFFFFF);
    try a.movv(1, 0xDDDDDDDDDDDDDDDD);
    try a.movr(2, 0);
    try a.movr(3, 1);

    std.debug.print("{X}\n", .{a.AL.items});

    var cpu = CPU.init(a.AL.items[0..]);
    cpu.fetchExecuteInstruction();
    cpu.fetchExecuteInstruction();
    cpu.fetchExecuteInstruction();
    cpu.fetchExecuteInstruction();

    std.debug.print("{any}\n",.{cpu});
}

