const std = @import("std");
const CPU = @import("cpu.zig");

const Allocator = std.mem.Allocator;
const Instruction = CPU.Instruction;
const BackingInt = @typeInfo(Instruction).Enum.tag_type;
const Self = @This();

const UnrRef = std.ArrayList(struct {
    label: []const u8,
    position: usize,
});

AL: std.ArrayList(u8),
HASH: std.StringArrayHashMap(usize),
UnresolvedReferences: UnrRef,

pub fn init(allocator: Allocator) Self {
    return .{
        .AL = std.ArrayList(u8).init(allocator),
        .HASH = std.StringArrayHashMap(usize).init(allocator),
        .UnresolvedReferences = UnrRef.init(allocator),
    };
}

pub fn assemblyToMachineCode(self: *Self, assembly: []const u8) !void {
    const writer = self.AL.writer();
    var line_it = std.mem.splitAny(u8, assembly, "\n");
    //const start = assembly.ptr;

    while (line_it.next()) |line| {
        if (line.len > 0 and line[0] == '.') {
            try self.HASH.put(line, writer.context.items.len);
            continue;
        }
        var tokens_it = std.mem.tokenizeAny(u8, line, " ,\t");
        const insToken = tokens_it.next() orelse return error.NoInstructionOnLine;
        const ins = try instructionFromLine(insToken);
        const arg1: ?u64 = if (tokens_it.next()) |token| blk: {
            break :blk try std.fmt.parseInt(u64, token, 0);
        } else null;

        var unresolvedRef = false;
        const arg2: ?u64 = if (tokens_it.next()) |token| outer: {
            if (token[0] == '.') {
                const value = self.HASH.get(token) orelse inner: {
                    try self.UnresolvedReferences.append(.{
                        .label = token,
                        .position = undefined,
                    });
                    unresolvedRef = true;
                    break :inner undefined;
                };
                break :outer value;
            }
            break :outer try std.fmt.parseInt(u64, token, 0);
        } else null;
        var offset: usize = 0;
        try self.writeInstruction(ins);
        offset += @sizeOf(Instruction);
        switch (ins) {
            .MOVV, .CMPV, .MOVVZ, .MOVVEG => {
                const addr = arg1 orelse return error.NoArg1;
                const val = arg2 orelse return error.NoArg2;
                try writer.writeByte(@intCast(addr));
                try self.writeInt(val);
                offset += @sizeOf(u8);

                if (unresolvedRef) {
                    const unref = self.UnresolvedReferences.items;
                    unref[unref.len - 1].position = writer.context.items.len - @sizeOf(u64);
                }
            },
            .JMPR, .INCR, .TESTR, .DECR => {
                const addr = arg1 orelse return error.NoArg1;
                try writer.writeByte(@intCast(addr));
                offset += @sizeOf(u8);
            },
            .OUTR => {
                const addr = arg1 orelse return error.NoArg1;
                const port = arg2 orelse return error.NoArg2;
                try writer.writeByte(@intCast(addr));
                try writer.writeByte(@intCast(port));
            },
            .HLT => {},
            else => |i| {
                std.debug.print("\n----- {any} -----\n", .{i});
                @panic("Not Implemented yet!");
            },
        }
    }
    for (self.UnresolvedReferences.items) |ref| {
        const addr = self.HASH.get(ref.label) orelse return error.NoLabelWithThatName;
        const T = @TypeOf(ref.position);
        var buffer: [@divExact(@typeInfo(T).Int.bits, 8)]u8 = undefined;
        std.mem.writeInt(T, &buffer, addr, CPU.Endian);
        try self.AL.replaceRange(ref.position, buffer.len, &buffer);
    }
}

pub fn instructionFromLine(text: []const u8) !Instruction {
    const info = @typeInfo(Instruction);
    inline for (info.Enum.fields) |field| {
        if (std.mem.eql(u8, field.name, text)) {
            return @field(Instruction, field.name);
        }
    }
    std.debug.print("\n----- {s} -----\n", .{text});
    return error.NotAValidInstruction;
}

fn writeInstruction(self: *Self, ins: Instruction) !void {
    const writer = self.AL.writer();
    try writer.writeInt(BackingInt, @intFromEnum(ins), CPU.Endian);
}

fn writeInt(self: *Self, value: anytype) !void {
    const writer = self.AL.writer();
    try writer.writeInt(@TypeOf(value), value, CPU.Endian);
}
