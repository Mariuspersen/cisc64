const std = @import("std");
const testing = std.testing;

const Self = @This();

// THE IDEA //
// a RISCV/CISC hybrid instruction set with no conditional jumps to tackle speculative execution attacks
// In recent times there as been a lot of attacks that target the branch predictor in modern CPU's to extract information
// The reason these sort of attacks are possible is because modern CPU's are pipelined ( I think )
// Reducing the need for flushing the pipeline, speculative execution and branch prediction is used
// This of course causes the above mention attacks

// What if we instead didnt have conditional jumps?
// We not longer need a branch predictor and speculative execution becomes just execution.

const Flag = u1;
const Register = u64;

const Instruction = enum(u16) {
    HLT = 0x0000,
    LDVR = 0x0A01, //0x0A01(LDRVR), 0xFF(Register Address), 0xFFFFFFFFFFFFFFFF(Value 64-Bit)
    LDRR = 0x0202, //0x0002, 0xFF, 0xFF,

    pub fn fetch(program: []const u8) Instruction {
        const intermediate: *[@divExact(@typeInfo(u16).Int.bits, 8)]u8 = @constCast(@ptrCast(program.ptr));
        const val: u16 = @bitCast(intermediate.*);
        return @enumFromInt(val);
    }

    pub fn len(self: *const Instruction) u8 {
        const number: u16 = @intFromEnum(self.*);
        const info = @typeInfo(Instruction);
        const tag = @typeInfo(info.Enum.tag_type);
        const length = number >> @divExact(tag.Int.bits, 2);
        return @intCast(length);
    }
};

pub fn sliceToType(program: []const u8, T: type) T {
    const info = @typeInfo(T);
    const len = switch (info) {
        .Int => |I| I.bits,
        .Float => |F| F.bits,
        .Struct => |S| @typeInfo(S.backing_integer.?).Int.bits,
        .Enum => |E| @typeInfo(E.tag_type).Int.bits,
        else => @compileError("Stop doing weird things!")
    };
    const intermediate: *[@divExact(len, 8)]u8 = @constCast(@ptrCast(program.ptr));
    const val: T = @bitCast(intermediate.*);
    return val;
}

pc: u64 = 0,
registers: [std.math.maxInt(u8)]Register,
program: []const u8,

pub fn init(program: []const u8) Self {
    return .{
        .pc = 0,
        .registers = std.mem.zeroes([std.math.maxInt(u8)]Register),
        .program = program,
    };
}

pub fn fetchExecuteInstruction(self: *Self) void {
    const ins = Instruction.fetch(self.program[self.pc..]);
    self.pc += 2;
    std.debug.print("{any}\n", .{ins});
    switch (ins) {
        .HLT => @panic("HALTED!"),
        .LDVR => {
            const addr = sliceToType(self.program[self.pc..], u8);
            self.pc += 1;
            const value = sliceToType(self.program[self.pc..], u64);
            self.pc += 8;

            self.registers[addr] = value;
            std.debug.print("{any} 0x{x}, 0x{x}\n", .{ins,addr,value});

        },
        .LDRR => {
            const addr1 = sliceToType(self.program[self.pc..], u8);
            self.pc += 1;
            const addr2 = sliceToType(self.program[self.pc..], u8);
            self.pc += 1;

            self.registers[addr1] = self.registers[addr2];
            std.debug.assert(self.registers[addr1] == self.registers[addr2]);
        }
    }
}
