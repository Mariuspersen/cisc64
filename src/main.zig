const std = @import("std");
const Cpu = @import("cpu");

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
    var cpu = Cpu.init(&program);
    cpu.fetchExecuteInstruction();
    std.debug.print("{X}\n",.{cpu.registers[0]});
    cpu.fetchExecuteInstruction();
    std.debug.print("{X}\n",.{cpu.registers[1]});
}

