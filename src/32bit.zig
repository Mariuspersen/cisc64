const Self = @This();
const std = @import("std");
const ISA = @import("isa.zig");

const Register = u32;
const Instruction = ISA.Instruction;
pub const Endian = std.builtin.Endian.little;

pub const IMMEDIATE_TYPE = enum(u2) {
    NONE,
    SHORT,
    WORD,
};

pub const FLAGSR = packed struct {
    zero: bool,
    equal: bool,
    greater: bool,
    lower: bool,
    carry: bool,
    sign: bool,
    overflow: bool,
    parity: bool,
    stack: bool,
    value: IMMEDIATE_TYPE,
    _: u21,
};

//Some addresses to named registers
const REMAINDER = 0xFF - 1;
const FLAGS_ADDR = 0xFF - 2;
const SP = 0xFF - 3;
const Stack = 0xFF - 4;

pc: u32 = 0,
registers: [std.math.maxInt(u8)]Register,
memory: [1024]u32 = undefined,

pub fn init() Self {
    return .{
        .pc = 0,
        .registers = std.mem.zeroes([std.math.maxInt(u8)]Register),
    };
}

pub fn load(self: *Self, bin: []u8) !void {
    const ins = @as([*]u32, @alignCast(@ptrCast(bin.ptr)))[0..@divExact(bin.len, @sizeOf(u32))];
    for (ins, self.memory[0..ins.len]) |value, *mem| {
        mem.* = value;
    }
}

pub fn fetchDecodeExecute(self: *Self) !?void {
    //Fetch
    const instruction: Instruction = @bitCast(self.memory[self.pc]);
    var flags: *FLAGSR = @ptrCast(&self.registers[FLAGS_ADDR]);
    //Decode
    const destination = instruction.destination;
    const source = instruction.source;
    const flagConditions: u8 = @truncate(self.registers[FLAGS_ADDR]);
    const insConditions: u8 = @bitCast(instruction.condition);

    if (flags.value != .NONE) {
        self.registers[SP] += 1;
        const offset = self.registers[SP];
        const top = self.registers[offset];
        self.registers[top] = switch (flags.value) {
            .WORD, .SHORT => @as(u32, @bitCast(instruction)),
            .NONE => return,
        };
        flags.value = .NONE;
        return;
    }

    const dest = switch (instruction.task.fetch) {
        .TO_MEMORY => &self.memory[self.registers[destination]],
        .FROM_MEMORY => &self.registers[destination],
        .REGISTER => &self.registers[destination],
        .IMMEDIATE => &self.registers[destination],
    };
    const val: u32 = switch (instruction.task.fetch) {
        .FROM_MEMORY => self.memory[self.registers[source]],
        .TO_MEMORY => self.registers[source],
        .REGISTER => self.registers[source],
        .IMMEDIATE => source,
    };

    const r = flagConditions & insConditions > 0;
    const c = insConditions != 0;

    switch (instruction.task.operation) {
        else => if (r and c) {} else if (r or c) return,
        .JMP, .CALL, .RET => if (insConditions != 0) return error.ConditionalOnJump,
    }
    //Execute
    switch (instruction.task.operation) {
        .ADD => {
            const result = @addWithOverflow(dest.*, val);
            dest.* = result[0];
            flags.carry = @bitCast(result[1]);
        },
        else => |ins| std.debug.panicExtra(
            @returnAddress(),
            "{any} is not implemented\n",
            .{ins},
        ),
    }
}
