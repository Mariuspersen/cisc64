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

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.debug.print("CPU Exception: {s}\n", .{msg});
    std.debug.print("Registers:\n", .{});
    var i: usize = 1;
    for (cpu.registers,0..) |register, j| {
        if (i % 5 == 0) std.debug.print("\n", .{});
        if (register == 0) continue;
        std.debug.print("REG{d:0>3}: 0x{x:0>16}    ", .{j,register});
        i += 1;
    }
    std.debug.print("\nMemory:\n", .{});
    for (cpu.memory) |memory| {
        if (memory == 0) continue;
        if (i % 5 == 0) std.debug.print("\n", .{});
        std.debug.print("0x{x:0>16}    ", .{memory});
        i += 1;
    }
    std.debug.print("\n", .{});
    std.builtin.default_panic(msg, error_return_trace, ret_addr);
}