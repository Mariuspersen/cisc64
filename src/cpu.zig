const std = @import("std");
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

const Flag = u1;
const Register = u64;
pub const Endian = std.builtin.Endian.little;

//Some addresses to named registers
const REMAINDER = 0xFF - 1;
const FLAGS_ADDR = 0xFF - 2;
const SP = 0xFF - 3;
const Stack = 0xFF - 4;

const IMMEDIATE_TYPE = enum(u2) {
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

//I think in the future the way this sure work is a Instruction is 2 bytes, the first byte is the conditional,
//it reads the flags and checks if should or should execute or skip the instruction

//For example maybe 0x0 means no conditional, so it executes the next instruction regardless
//If the conditional byte is 0x1, which is the eql flag, check the eql flag, if set execute instruction, otherwise skip

const Conditional = packed struct {
    zero: bool,
    equal: bool,
    greater: bool,
    lower: bool,
    carry: bool,
    sign: bool,
    overflow: bool,
    parity: bool,
};

const FT = enum(u2) {
    REGISTER,
    TO_MEMORY,
    FROM_MEMORY,
    IMMEDIATE,
};

const OP = enum(u6) {
    HLT,
    NOP,
    ADD,
    SUB,
    INC,
    DEC,
    XOR,
    OR,
    AND,
    MUL,
    DIV,
    SQRT,
    SR,
    SL,
    ITF, //Int to float,
    FTI, //Float to int,
    FADD,
    FSUB,
    FMUL,
    FDIV,
    FSQRT,
    JMP,
    MOV,
    CMP,
    SPI,
    RET,
    POP,
    CALL,
    PUSH,
    TEST,
    SWAP, //Swap Endianess
    BSF, // Bit Scan Forward (find first set bit)
    BSR, // Bit Scan Reverse (find last set bit)
    BTS, // Bit Test and Set
    BTR, // Bit Test and Reset
    XCHG, // Exchange values of two registers
    OUT,
    LI32, //Load Immediate Word
    LI64, //Load Immediate Long
    IN,
};

const Task = packed struct {
    fetch: FT, //Fetch type, value,register,memory
    operation: OP, //What actually is being executed
};

pub const Instruction = packed struct {
    condition: Conditional,
    task: Task,
    destination: u8,
    source: u8,

    pub fn fromToken(text: []const u8, dest: u8, source: u8) !Instruction {
        const OPInfo = @typeInfo(OP);
        var ins = std.mem.zeroInit(Instruction, .{});
        ins.destination = dest;
        ins.source = source;
        var OTLen: usize = 0;
        inline for (OPInfo.Enum.fields) |field| {
            if (std.ascii.startsWithIgnoreCase(text, field.name)) {
                ins.task.operation = @field(OP, field.name);
                OTLen = field.name.len;
            }
        }
        if (OTLen == 0) return error.InvalidInstruction;
        if (text.len == OTLen) return ins;
        ins.task.fetch = switch (text[OTLen]) {
            'T', 't' => .TO_MEMORY,
            'F', 'f' => .FROM_MEMORY,
            'R', 'r' => .REGISTER,
            'I', 'i' => .IMMEDIATE,
            else => blk: {
                OTLen -= 1;
                break :blk .IMMEDIATE;
            },
        };
        OTLen += 1;
        switch (ins.task.operation) {
            .CALL, .RET, .JMP => {
                if (text.len != OTLen) {
                    std.debug.print("Instructions that modify program counter cannot have conditionals!\n", .{});
                    return error.ConditionalOnJump;
                }
            },
            else => {}
        }
        for (text[OTLen..]) |c| switch (c) {
            'Z', 'z' => ins.condition.zero = true,
            'E', 'e' => ins.condition.equal = true,
            'G', 'g' => ins.condition.greater = true,
            'L', 'l' => ins.condition.lower = true,
            'C', 'c' => ins.condition.carry = true,
            'S', 's' => ins.condition.sign = true,
            'O', 'o' => ins.condition.overflow = true,
            'P', 'p' => ins.condition.parity = true,
            else => {
                std.debug.print("{c} is not a valid flag, ignoring...\n", .{c});
            },
        };

        return ins;
    }

    pub fn fetch(value: u64) [2]Instruction {
        return @bitCast(value);
    }

    pub fn toString(self: *const Instruction) [@sizeOf(Instruction)]u8 {
        return @bitCast(self.*);
    }
};

pub fn fetchDecodeExecute(self: *Self) !?void {
    //Fetch
    const bundle = Instruction.fetch(self.memory[self.pc]);
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
                .NONE => break,
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
        switch (instruction.task.operation) {
            .ADD => {
                const result = @addWithOverflow(dest.*, val);
                dest.* = result[0];
                flags.carry = @bitCast(result[1]);
            },
            .AND => {
                dest.* &= val;
            },
            .BSF => {
                dest.* = @ctz(val);
            },
            .BSR => {
                dest.* = @clz(val);
            },
            .BTS => {
                const truth = dest.* >> @intCast(val) & 1 == 1;
                flags.carry = truth;
                if (!truth) {
                    dest.* |= std.math.shl(u64, 1, val);
                }
            },
            .BTR => {
                const truth = dest.* >> @intCast(val) & 1 == 1;
                flags.carry = truth;
                if (!truth) {
                    dest.* &= ~(std.math.shl(u64, 1, val));
                }
            },
            .CALL => {
                const offset = self.registers[SP];
                self.registers[offset] = self.pc;
                self.registers[SP] -= 1;
                self.pc = switch (instruction.task.fetch) {
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
                self.pc = switch (instruction.task.fetch) {
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
                const intermediate: [@divExact(info.Int.bits, 8)]u8 = @bitCast(val);
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
                self.pc = self.registers[offset] + 1;
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
                const TBits = std.meta.Int(.unsigned, @typeInfo(T).Int.bits);
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
    self.pc += 1;
}

pc: u64 = 0,
registers: [std.math.maxInt(u8)]Register,
memory: [1024]u64 = undefined,

pub fn init() Self {
    return .{
        .pc = 0,
        .registers = std.mem.zeroes([std.math.maxInt(u8)]Register),
    };
}

pub fn load(self: *Self, bin: []u8) !void {
    const ins = @as([*]u64, @alignCast(@ptrCast(bin.ptr)))[0..@divExact(bin.len, @sizeOf(u64))];
    for (ins, self.memory[0..ins.len]) |value, *mem| {
        mem.* = value;
    }
}
