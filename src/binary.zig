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

    const input_filename = args.next() orelse return error.NoFileGiven;
    const input = try std.fs.cwd().openFile(input_filename, .{});
    const input_stat = try input.stat();
    const assembly = try input.readToEndAlloc(allocator, input_stat.size);
    defer input.close();
    defer allocator.free(assembly);

    const output_filename = args.next() orelse blk: {
        if (std.mem.lastIndexOfAny(u8, input_filename, ".")) |ext| {
            break :blk input_filename[0..ext];
        } else return error.InvalidInputFile;
    };

    const output = try std.fs.cwd().createFile(output_filename, .{});
    const writer = output.writer();
    defer output.close();
    
    var a = assembler.init(allocator);
    defer a.deinit();
    try a.assemblyToMachineCode(input_filename,assembly);

    const header = assembler.Header{
        .entry = a.start,
        .len = a.instructions.items.len,
        .size = @sizeOf(CPU.Instruction),
    };

    try writer.writeStructEndian(header, CPU.Endian);
    try a.writeInstructions(writer);
}

