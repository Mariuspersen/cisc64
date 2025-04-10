const std = @import("std");
const CPU = @import("cpu.zig");
const ISA = @import("isa.zig");

const Allocator = std.mem.Allocator;
const Instruction = ISA.Instruction;
const BackingInt = @typeInfo(Instruction).Enum.tag_type;
const Self = @This();

pub const MAGIC: u64 = @bitCast([_]u8{ 'C', 'I', 'S', 'C', '6', '4', 'L', 'E' });

pub const Yellow = "\x1b[38;2;255;255;0m";
pub const Red = "\x1b[38;2;255;0;0m";
pub const Reset = "\x1b[0m";
pub const Bold = "\x1b[1m";
pub const White = "\x1b[38;2;255;255;255m";

const LINE = Bold ++ White ++ "{s}:{d}:{d}:" ++ Reset ++ "\t{s}\n";
const WARNING = Bold ++ Yellow ++ "WARNING: " ++ Reset;
const ERROR = Bold ++ Red ++ "ERROR: " ++ Reset;

pub const Header = packed struct {
    magic: u64 = MAGIC,
    entry: u64, //address to the entry
    size: usize, //Size of the instruction
    len: usize, //Amount of those instructions
};

const Side = enum {
    DEST,
    SRC,
};

const Unresolved = struct {
    label: []const u8,
    position: usize,
    side: Side,
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
pub fn assemblyToMachineCode(self: *Self, filename: []const u8, assembly: []u8) !void {
    _ = std.mem.replace(u8, assembly, "\r", " ", assembly);
    var line_it = std.mem.splitAny(u8, assembly, "\n");
    var line_count: usize = 0;

    if (std.mem.indexOf(u8, assembly, ".data")) |i| {
        line_it.index = i;
        _ = line_it.next();
        
        while (line_it.next()) |untrimmed| : (line_count += 1) {
            const line = std.mem.trim(u8, untrimmed, " ");
            if (line.len <= 1) break;
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

    while (line_it.next()) |untrimmed| : (line_count += 1) {
        const line = std.mem.trim(u8, untrimmed, " ");
        errdefer std.debug.print(ERROR ++ LINE, .{ filename, line_count + 2, line.len, line });
        if (line.len <= 1) continue;

        if (std.mem.startsWith(u8, line, ".data")) {
            while (line_it.next()) |l| : (line_count += 1) {
                if (l.len <= 1) break;
            }
            continue;
        }

        var tokens_it = std.mem.tokenizeAny(u8, line, " ,\t");
        const text = tokens_it.next() orelse return error.NoInstructionOnLine;

        //Line is a comment, ignore
        if (std.ascii.startsWithIgnoreCase(text, "//")) continue;

        if (line[0] == '%') {
            const val = tokens_it.next() orelse return error.NoValueGiven;
            const parsed = try std.fmt.parseInt(u64, val, 0);
            try self.references.put(text, parsed);
            continue;
        }

        if (line[0] == '_' or line[0] == '.') {
            if (self.instructions.items.len % 2 != 0) {
                const padding = try Instruction.fromToken("nop", 0, 0);
                try self.instructions.append(padding);
                std.debug.print(WARNING ++ "Consider alignment, avoid nops\n", .{});
                std.debug.print(LINE, .{ filename, line_count + 1, line.len, line });
            }
            try self.references.put(line, self.instructions.items.len / 2);
            continue;
        }

        const dest = blk: {
            const token = tokens_it.next() orelse "0";
            errdefer std.debug.print(White ++ "\"{s}\"\n" ++ Reset, .{token});
            switch (token[0]) {
                '_', '.', '%' => {
                    const value = try self.checkReference(token, .DEST);
                    break :blk value;
                },
                else => {},
            }
            break :blk try std.fmt.parseInt(u64, token, 0);
        };

        const source = blk: {
            const token = tokens_it.next() orelse "0";
            errdefer std.debug.print(White ++ "\"{s}\"\n" ++ Reset, .{token});
            switch (token[0]) {
                '_', '.', '&', '%' => {
                    const value = try self.checkReference(token, .SRC);
                    break :blk value;
                },
                else => {},
            }
            break :blk try std.fmt.parseInt(u64, token, 0);
        };
        if (std.fmt.parseInt(u32, text, 0)) |immediate| {
            const last = self.instructions.getLast();
            if (last.task.operation == .LI32) {
                const value: Instruction = @bitCast(immediate);
                try self.instructions.append(value);
                continue;
            }
        } else |_| {}

        if (std.fmt.parseInt(u64, text, 0)) |immediate| {
            const last = self.instructions.getLast();
            if (last.task.operation == .LI64) {
                if (self.instructions.items.len % 2 != 0) {
                    const padding = try Instruction.fromToken("nop", 0, 0);
                    try self.instructions.append(padding);
                    std.debug.print(WARNING ++ "Consider alignment, avoid nops\n", .{});
                    std.debug.print(LINE, .{ filename, line_count + 1, line.len, line });
                }
                const values: [2]Instruction = @bitCast(immediate);
                for (values) |value| try self.instructions.append(value);
                continue;
            }
        } else |_| {}

        const instruction = try Instruction.fromToken(text, @truncate(dest), @truncate(source));

        switch (instruction.task.operation) {
            .CALL, .JMP => {
                if (self.instructions.items.len % 2 == 0) {
                    const padding = try Instruction.fromToken("nop", 0, 0);
                    try self.instructions.append(padding);
                    std.debug.print(WARNING ++ "Consider making call aligned\n", .{});
                    std.debug.print(LINE, .{ filename, line_count + 2, line.len, line });
                }
            },
            else => {}
        }
        try self.instructions.append(instruction);
    }

    for (self.unresolved.items) |ref| {
        errdefer std.debug.print("{s}\n", .{ref.label});
        const jumpaddr = self.references.get(ref.label) orelse return error.NoLabelByThatName;
        switch (ref.side) {
            .DEST => self.instructions.items[ref.position].destination = @intCast(jumpaddr),
            .SRC => self.instructions.items[ref.position].source = @intCast(jumpaddr),
        }
    }

    if (self.instructions.items.len % 2 != 0) {
        const padding = try Instruction.fromToken("nop", 0, 0);
        try self.instructions.append(padding);
        std.debug.print(WARNING ++ "Consider alignment, avoid nops\n", .{});
        std.debug.print(LINE, .{ filename,line_count+1, 0, "HERE" });
    }

    self.start = self.references.get(".start") orelse return error.NoStart;
}

fn checkReference(self: *Self, token: []const u8, side: Side) !usize {
    return self.references.get(token) orelse inner: {
        try self.unresolved.append(.{
            .label = token,
            .position = self.instructions.items.len,
            .side = side,
        });
        unresolvedRef = true;
        break :inner undefined;
    };
}

pub fn writeInstructions(self: *Self, writer: anytype) !void {
    for (self.instructions.items) |ins| try writer.writeStruct(ins);
}
