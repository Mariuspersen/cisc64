const std = @import("std");
const CPU = @import("cpu.zig");

const Allocator = std.mem.Allocator;
const Instruction = CPU.Instruction;
const BackingInt = @typeInfo(Instruction).Enum.tag_type;
const Self = @This();

const Unresolved = struct {
    label: []const u8,
    position: usize,
};

const Unresolvables = std.ArrayList(Unresolved);
const Instructions = std.ArrayList(Instruction);
const References = std.StringHashMap(usize);

instructions: Instructions,
references: References,
unresolved: Unresolvables,

pub fn init(allocator: Allocator) Self {
    return .{
        .instructions = Instructions.init(allocator),
        .references = References.init(allocator),
        .unresolved = Unresolvables.init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.instructions.deinit();
    self.references.deinit();
    self.unresolved.deinit();
}

var unresolvedRef = false;
pub fn assemblyToMachineCode(self: *Self, filename: []const u8, assembly: []const u8) !void {
    var line_it = std.mem.splitAny(u8, assembly, "\n\r");
    var line_count: usize = 0;

    if (std.mem.indexOf(u8, assembly, ".data")) |i| {
        line_it.index = i;
        _ = line_it.next();
        while (line_it.next()) |line| : (line_count += 1) {
            if (line.len == 0) break;
            var tokens = std.mem.tokenizeAny(u8, line, " \t");
            const decl = tokens.next() orelse return error.DataNoDecl;
            const val = tokens.next() orelse return error.DataNoDecl;
            const number = try std.fmt.parseInt(u64, val, 0);
            try self.references.put(decl, self.instructions.items.len);
            const memory: [2]Instruction = @bitCast(number);
            for (memory) |value| try self.instructions.append(value);
        }
    }

    line_it.reset();
    line_count = 0;

    while (line_it.next()) |line| : (line_count += 1) {
        errdefer std.debug.print("{s}:{d}:{d}:\t{s}\n", .{ filename, line_count + 1, line.len, line });
        if (std.mem.startsWith(u8, line, ".data")) {
            while (line_it.next()) |l| {
                if (l.len == 0) break;
            }
        }
        const index = std.mem.indexOfAny(u8, line, "%") orelse continue;
        if (index != 0) continue;
        var tokens_it = std.mem.tokenizeAny(u8, line, " \t");
        const decl = tokens_it.next() orelse return error.NoDecleration;
        const val = tokens_it.next() orelse return error.NoValueGiven;
        const parsed = try std.fmt.parseInt(u8, val, 0);
        try self.references.put(decl, parsed);
    }

    line_it.reset();
    line_count = 0;

    while (line_it.next()) |line| : (line_count += 1) {
        if (std.mem.startsWith(u8, line, ".data")) {
            while (line_it.next()) |l| {
                if (l.len == 0) break;
            }
        }
        errdefer std.debug.print("{s}:{d}:{d}:\t{s}\n", .{ filename, line_count + 1, line.len, line });
        const index = std.mem.indexOfAny(u8, line, "._") orelse continue;
        if (index != 0) continue;
        var tokens_it = std.mem.tokenizeAny(u8, line, " \t");
        const decl = tokens_it.next() orelse return error.NoDecleration;
        if (self.instructions.items.len % 2 != 0) {
            try self.instructions.append(try Instruction.fromToken("NOP", 0, 0));
        }
        try self.references.put(decl, @intCast(self.instructions.items.len));
    }

    line_it.reset();
    line_count = 0;

    while (line_it.next()) |line| : (line_count += 1) {
        errdefer std.debug.print("{s}:{d}:{d}:\t{s}\n", .{ filename, line_count + 1, line.len, line });
        if (std.mem.startsWith(u8, line, ".data")) {
            while (line_it.next()) |l| {
                if (l.len == 0) break;
            }
        }
        if (line.len == 0) continue;
        if (line[0] == '%') continue;
        if (std.mem.indexOfAny(u8, line, "._")) |i| {
            if (i == 0) {
                try self.references.put(line, @intCast(self.instructions.items.len));
                continue;
            }
        }
        var tokens_it = std.mem.tokenizeAny(u8, line, " ,\t");
        const text = tokens_it.next() orelse return error.NoInstructionOnLine;

        const dest = blk: {
            const token = tokens_it.next() orelse "0";
            switch (token[0]) {
                '_', '.' => {
                    const value = try self.checkReference(token);
                    break :blk value;
                },
                '%' => {
                    break :blk self.references.get(token) orelse return error.UndeclaredUsed;
                },
                else => {},
            }
            break :blk try std.fmt.parseInt(u8, token, 0);
        };
        const source = blk: {
            const token = tokens_it.next() orelse "0";
            switch (token[0]) {
                '_', '.', '&' => {
                    const value = try self.checkReference(token);
                    break :blk value;
                },
                '%' => {
                    break :blk self.references.get(token) orelse return error.UndeclaredUsed;
                },
                else => {},
            }
            break :blk try std.fmt.parseInt(u8, token, 0);
        };
        const instruction = try Instruction.fromToken(text, @intCast(dest), @intCast(source));
        try self.instructions.append(instruction);
    }
}

fn checkReference(self: *Self, token: []const u8) !usize {
    return self.references.get(token) orelse inner: {
        try self.unresolved.append(.{
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

pub fn writeInstructions(self: *Self, writer: anytype) !void {
    for (self.instructions.items) |ins| try writer.writeStruct(ins);
}
