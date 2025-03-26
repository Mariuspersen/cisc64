const std = @import("std");
const CPU = @import("cpu.zig");
const assembler = @import("assembler.zig");

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

    var cpu = CPU.init();
    try cpu.load(program);
    cpu.pc = header.entry;

    while (try cpu.fetchDecodeExecute()) |_| {}
    return;
}