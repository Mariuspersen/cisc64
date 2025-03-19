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
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();

    const filename = args.next() orelse return error.NoFileGiven;

    const file = try std.fs.cwd().openFile(filename, .{});
    const stat = try file.stat();
    const content = try file.readToEndAlloc(allocator, stat.size);
    defer allocator.free(content);

    var a = assembler.init(allocator);
    defer a.deinit();

    try a.assemblyToMachineCode(filename,content);

    var cpu = CPU.init(a.AL.items[0..]);
    cpu.pc = a.HASH.get(".start").?;

    while (cpu.fetchExecuteInstruction()) |_| {
    }
    std.debug.print("\n", .{});
}

