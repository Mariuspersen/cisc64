const emulator = @import("emulator.zig");
const assembler = @import("binary.zig");
pub fn main() !void {
    try assembler.main();
    try emulator.main();
}