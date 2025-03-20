const std = @import("std");
const CPU = @import("cpu.zig");

const Allocator = std.mem.Allocator;
const Instruction = CPU.Instruction;
const BackingInt = @typeInfo(Instruction).Enum.tag_type;
const Self = @This();

const Reference = struct {
    label: []const u8,
    position: usize,
};

const Refs = std.ArrayList(Reference);

AL: std.ArrayList(u8),
HASH: std.StringHashMap(usize),
UnresolvedReferences: Refs,

pub fn init(allocator: Allocator) Self {
    return .{
        .AL = std.ArrayList(u8).init(allocator),
        .HASH = std.StringHashMap(usize).init(allocator),
        .UnresolvedReferences = Refs.init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.AL.deinit();
    self.HASH.deinit();
    self.UnresolvedReferences.deinit();
}

var unresolvedRef = false;
pub fn assemblyToMachineCode(self: *Self, filename: []const u8, assembly: []const u8) !void {
    const writer = self.AL.writer();
    var line_it = std.mem.splitAny(u8, assembly, "\n\r");
    var line_count: usize = 0;

    while (line_it.next()) |line| : (line_count += 1) {
        errdefer std.debug.print("{s}:{d}:{d}:\t{s}\n", .{ filename, line_count + 1, line.len, line });
        const index = std.mem.indexOfAny(u8, line, "%") orelse continue;
        if (index != 0) continue;
        var tokens_it = std.mem.tokenizeAny(u8, line, " \t");
        const decl= tokens_it.next() orelse return error.NoDecleration;
        const val = tokens_it.next() orelse return error.NoValueGiven;
        const parsed = try std.fmt.parseInt(u64, val, 0);
        try self.HASH.put(decl, parsed);
    }

    line_it.reset();
    line_count = 0;

    while (line_it.next()) |line| : (line_count += 1) {
        errdefer std.debug.print("{s}:{d}:{d}:\t{s}\n", .{ filename, line_count + 1, line.len, line });
        if (line.len == 0) continue;
        if (line[0] == '%') continue;
        if (std.mem.indexOfAny(u8, line, "._")) |i| {
            if (i == 0) {
                try self.HASH.put(line, writer.context.items.len);
                continue;
            }
        }
        var tokens_it = std.mem.tokenizeAny(u8, line, " ,\t");
        const insToken = tokens_it.next() orelse return error.NoInstructionOnLine;
        const ins = try instructionFromLine(insToken);
        const arg1: ?u64 = if (tokens_it.next()) |token| blk: {
            switch (token[0]) {
                '_', '.' => {
                    const value = try self.checkReference(token);
                    break :blk value;
                },
                '%' => {
                    break :blk self.HASH.get(token) orelse return error.UndeclaredUsed;
                },
                else => {}
            }
            break :blk try std.fmt.parseInt(u64, token, 0);
        } else null;

        const arg2: ?u64 = if (tokens_it.next()) |token| outer: {
            switch (token[0]) {
                '_', '.' => {
                    const value = try self.checkReference(token);
                    break :outer value;
                },
                '%' => {
                    break :outer self.HASH.get(token) orelse return error.UndeclaredUsed;
                },
                else => {}
            }
            break :outer try std.fmt.parseInt(u64, token, 0);
        } else null;
        var offset: usize = 0;
        try self.writeInstruction(ins);
        offset += @sizeOf(Instruction);
        switch (ins) {
            .MOVV, .CMPV, .MOVVZ, .MOVVEG, .MOVVL => {
                const addr = arg1 orelse return error.NoArg1;
                const val = arg2 orelse return error.NoArg2;
                try writer.writeByte(@intCast(addr));
                try self.writeInt(val);
                offset += @sizeOf(u8);

                if (unresolvedRef) {
                    const unref = self.UnresolvedReferences.items;
                    unref[unref.len - 1].position = writer.context.items.len - @sizeOf(u64);
                    unresolvedRef = !unresolvedRef;
                }
            },
            .JMPR, .INCR, .TESTR, .DECR, .PUSHR, .POPR => {
                const addr = arg1 orelse return error.NoArg1;
                try writer.writeByte(@intCast(addr));
                offset += @sizeOf(u8);
            },
            .CALLV => {
                const addr = arg1 orelse return error.NoArg1;
                try self.writeInt(addr);
            },
            .OUTR, .SUBR, .ADDR => {
                const addr = arg1 orelse return error.NoArg1;
                const port = arg2 orelse return error.NoArg2;
                try writer.writeByte(@intCast(addr));
                try writer.writeByte(@intCast(port));
            },
            .HLT, .SPI, .RET => {},
            else => |i| {
                std.debug.print("\n----- {any} -----\n", .{i});
                return error.NotYetImplemented;
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

fn checkReference(self: *Self, token: []const u8) !u64 {
    return self.HASH.get(token) orelse inner: {
        try self.UnresolvedReferences.append(.{
            .label = token,
            .position = undefined,
        });
        unresolvedRef = true;
        break :inner undefined;
    };
}

const NAME_MAX_LEN = blk: {
    const info = @typeInfo(Instruction);
    var len = 0;
    for (info.Enum.fields) |field| {
        if (field.name.len > len) {
            len = field.name.len;
        }
    }
    break :blk len;
};

pub fn instructionFromLine(text: []const u8) !Instruction {
    const info = @typeInfo(Instruction);
    var buf: [NAME_MAX_LEN]u8 = undefined;
    for (text, buf[0..text.len]) |c, *d| {
        d.* = std.ascii.toUpper(c);
    }
    inline for (info.Enum.fields) |field| {
        if (std.mem.eql(u8, field.name, buf[0..text.len])) {
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
