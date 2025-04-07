const std = @import("std");
const ISA = @import("isa.zig");
const testing = std.testing;

const Self = @This();

// THE IDEA //
// a RISC/CISC hybrid instruction set with no conditional jumps to tackle speculative execution attacks
// In recent times there as been a lot of attacks that target the branch predictor in modern CPU's to extract information
// The reason these sort of attacks are possible is because modern CPU's are pipelined ( I think )
// Reducing the need for flushing the pipeline, speculative execution and branch prediction is used
// This of course causes the above mention attacks

// What if we instead didnt have conditional jumps?
// We not longer need a branch predictor and speculative execution becomes just execution.

//Some 3AM thoughts about SIMD-at-home implementations
//Special addressing mode allowing multiple register addressing bus into a mask
//Meaning a flag is set, instead of 0x0F addressing that register at that address, it enables select for half of the lower registers
//Now have two of these 8-Bit to 256 select lines, twice and you have read enable and write enable
//The lowest amount of registers you can address in this special mode would be 256 / 8
//Each register would need its own ALU and FPU for arithmatic operations

//Wait is this just a GPU at this point?
//A General Processing Unit?
//Hmmmmmm
pub const IMMEDIATE_TYPE = enum(u2) {
    NONE,
    SHORT,
    WORD,
    LONG,
};

const FLAGSR = packed struct {
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
    _: u53,
};

const Register = u64;
pub const Endian = std.builtin.Endian.little;

//Some addresses to named registers
const PC = 0xFF - 1;
const REMAINDER = 0xFF - 2;
const FLAGS_ADDR = 0xFF - 3;
const SP = 0xFF - 4;
const Stack = 0xFF - 5;

const Instruction = ISA.Instruction;

pub fn fetchDecodeExecute(self: *Self) !?void {
    //Fetch
    const bundle = Instruction.fetch(self.memory[self.registers[PC]]);
    var flags: *FLAGSR = @ptrCast(&self.registers[FLAGS_ADDR]);
    //Decode
    for (bundle) |instruction| {
        errdefer std.debug.print("{any}\n", .{instruction});

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
                .LONG => @bitCast(bundle),
                .NONE => 0,
            };
            flags.value = .NONE;
            break;
        }

        const dest = switch (instruction.task.fetch) {
            .TO_MEMORY => &self.memory[self.registers[destination]],
            .FROM_MEMORY => &self.registers[destination],
            .REGISTER => &self.registers[destination],
            .IMMEDIATE => &self.registers[destination],
        };
        const val: u64 = switch (instruction.task.fetch) {
            .FROM_MEMORY => self.memory[self.registers[source]],
            .TO_MEMORY => self.registers[source],
            .REGISTER => self.registers[source],
            .IMMEDIATE => source,
        };

        const r = flagConditions & insConditions > 0;
        const c = insConditions != 0;

        switch (instruction.task.operation) {
            else => if (r and c) {} else if (r or c) continue,
            .JMP, .CALL, .RET => if (insConditions != 0) return error.ConditionalOnJump,
        }
        //Execute
        switch (instruction.task.operation) 
        {
            .ADD => {
                const result = @addWithOverflow(dest.*, val);
                dest.* = result[0];
                flags.carry = @bitCast(result[1]);
            },
            .AND => {
                dest.* &= val;
            },
            .BFS => {
                dest.* = @ctz(val);
            },
            .BRS => {
                dest.* = @clz(val);
            },
            .BT => {
                flags.carry = dest.* >> @intCast(val) & 1 == 1;
            },
            .BS => {
                dest.* |= std.math.shl(u64, 1, val);
            },
            .BC => {
                dest.* &= ~(std.math.shl(u64, 1, val));
            },
            .CALL => {
                const offset = self.registers[SP];
                self.registers[offset] = self.registers[PC];
                self.registers[SP] -= 1;
                self.registers[PC] = switch (instruction.task.fetch) {
                    .IMMEDIATE => destination,
                    else => dest.*,
                };
                return;
            },
            .CMP => {
                flags.equal = dest.* == val;
                flags.greater = dest.* > val;
                flags.lower = dest.* < val;
            },
            .DEC => {
                const result = @subWithOverflow(dest.*, 1);
                dest.* = result[0];
                flags.zero = @bitCast(result[1]);
            },
            .DIV => {
                dest.* = @divTrunc(dest.*, val);
                self.registers[REMAINDER] = @rem(dest.*, val);
            },
            .FADD => {
                const destF: f64 = @bitCast(dest.*);
                const valF: f64 = @bitCast(val);
                const result: f64 = destF + valF;
                dest.* = @bitCast(result);
            },
            .FDIV => {
                const destF: f64 = @bitCast(dest.*);
                const valF: f64 = @bitCast(val);
                const result = destF / valF;
                dest.* = @bitCast(result);
            },
            .FMUL => {
                const destF: f64 = @bitCast(dest.*);
                const valF: f64 = @bitCast(val);
                const result = destF * valF;
                dest.* = @bitCast(result);
            },
            .FSQRT => {
                const valF: f64 = @bitCast(val);
                const result: f64 = @sqrt(valF);
                dest.* = @bitCast(result);
            },
            .FSUB => {
                const destF: f64 = @bitCast(dest.*);
                const valF: f64 = @bitCast(val);
                const result = destF - valF;
                dest.* = @bitCast(result);
            },
            .FTI => {
                const valF: f64 = @bitCast(val);
                dest.* = @intFromFloat(valF);
            },
            .HLT => {
                return null;
            },
            .INC => {
                const result = @addWithOverflow(dest.*, 1);
                dest.* = result[0];
                flags.carry = @bitCast(result[1]);
            },
            .ITF => {
                const valF: f64 = @floatFromInt(val);
                dest.* = @bitCast(valF);
            },
            .JMP => {
                self.registers[PC] = switch (instruction.task.fetch) {
                    .IMMEDIATE => destination,
                    else => dest.*,
                };
                return;
            },
            .LI32 => {
                const offset = self.registers[SP];
                self.registers[offset] = destination;
                self.registers[SP] -= 1;
                flags.value = .WORD;
            },
            .LI64 => {
                const offset = self.registers[SP];
                self.registers[offset] = destination;
                self.registers[SP] -= 1;
                flags.value = .LONG;
                break;
            },
            .MOV => {
                dest.* = val;
            },
            .MUL => {
                const result = @mulWithOverflow(dest.*, val);
                dest.* = result[0];
                flags.carry = @bitCast(result[1]);
            },
            .NOP => {},
            .OUT => {
                const handle = switch (@import("builtin").os.tag) {
                    .windows => std.os.windows.peb().ProcessParameters.hStdOutput,
                    else => @as(i32, @intCast(destination)),
                };
                const info = @typeInfo(Register);
                const writer = (std.fs.File{ .handle = handle }).writer();
                const intermediate: [@divExact(info.@"int".bits, 8)]u8 = @bitCast(val);
                for (intermediate) |value| {
                    if (value == 0) break;
                    try writer.writeByte(value);
                }
            },
            .IN => {
                const handle = switch (@import("builtin").os.tag) {
                    .windows => std.os.windows.peb().ProcessParameters.hStdInput,
                    else => @as(i32, @intCast(destination)),
                };
                const reader = (std.fs.File{ .handle = handle }).reader();
                dest.* = try reader.readByte();
            },
            .OR => {
                dest.* |= val;
            },
            .POP => {
                self.registers[SP] += 1;
                const offset = self.registers[SP];
                const top = self.registers[offset];
                dest.* = top;
            },
            .PUSH => {
                const offset = self.registers[SP];
                self.registers[offset] = dest.*;
                self.registers[SP] -= 1;
            },
            .RET => {
                self.registers[SP] += 1;
                const offset = self.registers[SP];
                self.registers[PC] = self.registers[offset] + 1;
                return;
            },
            .SL => {
                dest.* <<= @intCast(val);
            },
            .SPI => {
                self.registers[SP] = Stack;
                flags.stack = true;
            },
            .SQRT => {
                dest.* = std.math.sqrt(val);
            },
            .SR => {
                dest.* >>= @intCast(val);
            },
            .SUB => {
                dest.* -= val;
            },
            .TEST => {
                flags.zero = val == 0;
                const T = @TypeOf(dest.*);
                const TBits = std.meta.Int(.unsigned, @typeInfo(T).@"int".bits);
                flags.sign = @as(TBits, @bitCast(dest.*)) >> (@bitSizeOf(T) - 1) != 0;
            },
            .SWAP => {
                dest.* = @byteSwap(val);
            },
            .XCHG => {
                const ptr = switch (instruction.task.fetch) {
                    .FROM_MEMORY => &self.memory[self.registers[source]],
                    .TO_MEMORY => &self.registers[source],
                    .REGISTER => &self.registers[source],
                    .IMMEDIATE => continue,
                };
                dest.* ^= ptr.*;
                ptr.* ^= dest.*;
                dest.* ^= ptr.*;
            },
            .XOR => {
                dest.* ^= val;
            },
        }
    }
    self.registers[PC] += 1;
}

registers: [std.math.maxInt(u8)]Register,
memory: [1024]u64 = undefined,

pub fn init() Self {
    return .{
        .registers = std.mem.zeroes([std.math.maxInt(u8)]Register),
    };
}

pub fn setPC(self: *Self, val: u64) void {
    self.registers[PC] = val;
}

pub fn load(self: *Self, bin: []u8) !void {
    const ins = @as([*]u64, @alignCast(@ptrCast(bin.ptr)))[0..@divExact(bin.len, @sizeOf(u64))];
    for (ins, self.memory[0..ins.len]) |value, *mem| {
        mem.* = value;
    }
}
