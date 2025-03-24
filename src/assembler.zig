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
start: usize = 0,

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
            const val = tokens.next() orelse return error.DataNoVal;
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
        if (line.len == 0) continue;

        if (std.mem.startsWith(u8, line, ".data")) {
            while (line_it.next()) |l| : (line_count += 1) {
                if (l.len == 0) break;
            }
            continue;
        }

        var tokens_it = std.mem.tokenizeAny(u8, line, " ,\t");
        const text = tokens_it.next() orelse return error.NoInstructionOnLine;
        if (line[0] == '%') {
            const val = tokens_it.next() orelse return error.NoValueGiven;
            const parsed = try std.fmt.parseInt(u64, val, 0);
            try self.references.put(text, parsed);
            continue;
        }
        if (line[0] == '_' or line[0] == '.') {
            if (self.instructions.items.len % 2 != 0) return error.JumpPointNotAligned8Bytes;
            try self.references.put(line, self.instructions.items.len / 2);
            continue;
        }

        const dest = blk: {
            const token = tokens_it.next() orelse "0";
            errdefer std.debug.print("\"{s}\" <---- this\n", .{token});
            switch (token[0]) {
                '_', '.', '%' => {
                    const value = try self.checkReference(token);
                    break :blk value;
                },
                else => {},
            }
            break :blk try std.fmt.parseInt(u64, token, 0);
        };
        const source = blk: {
            const token = tokens_it.next() orelse "0";
            errdefer std.debug.print("\"{s}\" <---- this\n", .{token});
            switch (token[0]) {
                '_', '.', '&', '%' => {
                    const value = try self.checkReference(token);
                    break :blk value;
                },
                else => {},
            }
            break :blk try std.fmt.parseInt(u64, token, 0);
        };
        const instruction = try Instruction.fromToken(text, @intCast(dest), @intCast(source));
        try self.instructions.append(instruction);
    }
    for (self.unresolved.items) |ref| {
        errdefer std.debug.print("{s}\n", .{ref.label});
        const jumpaddr = self.references.get(ref.label) orelse return error.NoLabelByThatName;
        std.debug.print("{d} {s} {d} {any}\n", .{jumpaddr, ref.label,ref.position,self.instructions.items[ref.position]});
        self.instructions.items[ref.position].destination = @intCast(jumpaddr / 2);
    }
    self.start = self.references.get(".start") orelse return error.NoStart;

    var ref_it = self.references.iterator();
    while (ref_it.next()) |ref| {
        std.debug.print("{s} {d}\n", .{ref.key_ptr.*,ref.value_ptr.*});
    }
    for (self.instructions.items) |ins| {
        std.debug.print("{any} {d} {d}\n", .{ins.task.operation, ins.destination, ins.source });
    }
}

fn checkReference(self: *Self, token: []const u8) !usize {
    return self.references.get(token) orelse inner: {
        try self.unresolved.append(.{
            .label = token,
            .position = self.instructions.items.len,
        });
        unresolvedRef = true;
        break :inner undefined;
    };
}

pub fn writeInstructions(self: *Self, writer: anytype) !void {
    for (self.instructions.items) |ins| try writer.writeStruct(ins);
}
