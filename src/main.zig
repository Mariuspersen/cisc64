const emulator = @import("emulator.zig");
const assembler = @import("binary.zig");
const std = @import("std");

pub fn main() !void {
    try assembler.main();
    try emulator.main();
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    emulator.panic(msg, error_return_trace, ret_addr);
}