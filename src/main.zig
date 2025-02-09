const std = @import("std");
const Cpu = @import("cpu");

const program = [_]u8{
    0x01,
    0x05,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
};

pub fn main() !void {
    var cpu = Cpu.init();
    cpu.fetchExecuteInstruction(&program);
    std.debug.print("{any}",.{cpu});
}

