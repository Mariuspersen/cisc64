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

    const file = try std.fs.cwd().openFile("src/test.s", .{});
    const stat = try file.stat();
    const content = try file.readToEndAlloc(allocator, stat.size);

    var a = assembler.init(allocator);
    try a.assemblyToMachineCode(content);

    std.debug.print("{X}\n", .{a.AL.items});

    var cpu = CPU.init(a.AL.items[0..]);

    cpu.pc = a.HASH.get(".start").?;

    while (cpu.fetchExecuteInstruction()) |_| {
        std.debug.print("{any}\n",.{cpu});

    }
}

