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

    const filename = args.next() orelse return error.NoFileGiven;

    const file = try std.fs.cwd().openFile(filename, .{});
    const stat = try file.stat();
    const content = try file.readToEndAlloc(allocator, stat.size);
    defer allocator.free(content);

    var a = assembler.init(allocator);
    defer a.deinit();

    try a.assemblyToMachineCode(filename,content);

    var program = std.ArrayList(u8).init(allocator);
    defer program.deinit();
    const wprog = program.writer();
    try a.writeInstructions(wprog);

    var cpu = CPU.init();
    try cpu.load(wprog.context.items);
    cpu.pc = a.start;

    while (try cpu.fetchDecodeExecute()) |_| {
    }
    std.debug.print("\n", .{});
}

