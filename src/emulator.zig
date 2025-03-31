const std = @import("std");
const CPU = @import("cpu.zig");
const assembler = @import("assembler.zig");


var cpu = CPU.init();
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();

    const filename = blk: {
        if (args.next()) |arg| {
            if (std.mem.endsWith(u8, arg, ".s"))
            if (std.mem.lastIndexOfAny(u8, arg, ".")) |ext| {
                break :blk arg[0..ext];
            };
            break :blk arg;
        } else return error.NoInputFile;
    };

    const file = try std.fs.cwd().openFile(filename, .{});
    const reader = file.reader();
    const header = try reader.readStructEndian(assembler.Header,CPU.Endian);

    if(header.magic != assembler.MAGIC) {
        std.debug.print("Header MAGIC missmatch: {} should be {}\n", .{header.magic,assembler.MAGIC});
        return error.HeaderMismatch;
    }
    const program = try reader.readAllAlloc(allocator, header.size*header.len);
    defer allocator.free(program);

    try cpu.load(program);
    cpu.pc = header.entry;

    while (try cpu.fetchDecodeExecute()) |_| {}
    return;
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    stderr.print("CPU Exception: {s}\n", .{msg}) catch {};
    stderr.print("Registers:\n", .{}) catch {};
    var i: usize = 1;
    for (cpu.registers,0..) |register, j| {
        if (i % 5 == 0) stderr.print("\n", .{}) catch {};
        if (register == 0) continue;
        stderr.print("REG{d:0>3}: 0x{x:0>16}    ", .{j,register}) catch {};
        i += 1;
    }
    stderr.print("\nMemory:\n", .{}) catch {};
    for (cpu.memory) |memory| {
        if (memory == 0) continue;
        if (i % 5 == 0) stderr.print("\n", .{}) catch {};
        stderr.print("0x{x:0>16}    ", .{memory}) catch {};
        i += 1;
    }
    stderr.print("\n", .{}) catch {};
    std.debug.defaultPanic(msg, ret_addr);
}