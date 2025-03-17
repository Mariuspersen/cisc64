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

    while (line_it.next()) |line| {
        if (line.len > 0 and line[0] == '.') {
            try self.HASH.put(line, writer.context.items.len);
            continue;
        }
        var tokens_it = std.mem.tokenizeAny(u8, line, " ,\t");
        const insToken = tokens_it.next() orelse return error.NoInstructionOnLine;
        const ins = try instructionFromLine(insToken);
        const arg1: ?u64 =  if(tokens_it.next()) |token| blk: {
            break :blk try std.fmt.parseInt(u64, token, 0);
        } else null;

        const arg2: ?u64 = if (tokens_it.next()) |token| blk: {
            if (token[0] == '.') {
                std.debug.print("TOKEN: {s} {d}\n", .{token,writer.context.items.len});
                const value = self.HASH.get(token) orelse inner: {
                    try self.UnresolvedReferences.append(.{
                        .label = token,
                        .position = writer.context.items.len,
                    });
                    break :inner 0;
                };
                break :blk value;
            }
            break :blk try std.fmt.parseInt(u64, token, 0);
        } else null;

        try self.writeInstruction(ins);
        switch (ins) {
            .MOVV => {
                try writer.writeByte(@intCast(arg1 orelse return error.NoArg1));
                try self.writeInt(arg2 orelse return error.NoArg2);
            },
            .DECR => {
                try writer.writeByte(@intCast(arg1 orelse return error.NoArg1));
            },
            .CMPV => {
                try self.cmpv(@intCast(arg1 orelse return error.NoArg1), arg2 orelse return error.NoArg2,);
            },
            .MOVVZ => {
                try writer.writeByte(@intCast(arg1 orelse return error.NoArg1));
                try self.writeInt(arg2 orelse return error.NoArg2);
            },
            .TEST => {
                try writer.writeByte(@intCast(arg1 orelse return error.NoArg1));
            },
            .JMPR => {
                try writer.writeByte(@intCast(arg1 orelse return error.NoArg1));
            },
            .INCR => {
                try writer.writeByte(@intCast(arg1 orelse return error.NoArg1));
            },
            .HLT => {},
            .MOVVEG => {
                try writer.writeByte(@intCast(arg1 orelse return error.NoArg1));
                try self.writeInt(arg2 orelse return error.NoArg2);
            },
            else => |i| {
                std.debug.print("\n----- {any} -----\n", .{i});
                @panic("Not Implemented yet!");
            }
        }
    }
    for (self.UnresolvedReferences.items) |ref| {
        const addr = self.HASH.get(ref.label) orelse return error.NoLabelWithThatName;
        const T = @TypeOf(ref.position);
        var buffer: [@divExact(@typeInfo(T).Int.bits, 8)]u8 = undefined;
        std.mem.writeInt(T, &buffer, addr,CPU.Endian);
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

pub fn movr(self: *Self, dest: u8, src: u8) !void {
    const writer = self.AL.writer();
    try self.writeInstruction(.MOVR);
    try writer.writeByte(dest);
    try writer.writeByte(src);
}

pub fn jmpr(self: *Self, reg: u8) !void {
    const writer = self.AL.writer();
    try self.writeInstruction(.JMPR);
    try writer.writeByte(reg);
}

pub fn cmpv(self: *Self, reg: u8, val: u64) !void {
    const writer = self.AL.writer();
    try self.writeInstruction(.CMPV);
    try writer.writeByte(reg);
    try self.writeInt(val);
}