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
const MMU = 0x00;
const FLAGS_ADDR = 0xFE;
const SP = 0xFD;
const Stack = 0xFC;

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
    _: u55,
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
    NONE,
    REGISTER,
    MEMORY,
    VALUE,
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
    SWAPE, //Swap Endianess
    BSF, // Bit Scan Forward (find first set bit)
    BSR, // Bit Scan Reverse (find last set bit)
    BTS, // Bit Test and Set
    BTR, // Bit Test and Reset
    XCHG, // Exchange values of two registers
    OUT,
};

const Task = packed struct {
    fetch: FT, //Fetch type, value,register,memory
    operation: OP, //What actually is being executed
};

const NAME_MAX_LEN = blk: {
    const info = @typeInfo(OP);
    const cinfo = @typeInfo(Conditional);
    var len = 0;
    for (info.Enum.fields) |field| {
        if (field.name.len > len) {
            len = field.name.len;
        }
    }
    break :blk len + cinfo.Struct.fields.len + 1;
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
            'N', 'n' => .NONE,
            'M', 'm' => .MEMORY,
            'R', 'r' => .REGISTER,
            'V', 'v' => .VALUE,
            else => blk: {
                OTLen -= 1;
                break :blk .NONE;
            },
        };
        OTLen += 1;
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
        const dest = instruction.destination;
        const source = instruction.source;
        const flagConditions: u8 = @truncate(self.registers[FLAGS_ADDR]);
        const insConditions: u8 = @bitCast(instruction.condition);
        
        const r = flagConditions & insConditions > 0;
        const c = insConditions != 0;

        switch (instruction.task.operation) {
            else => if (r and c) {} else if (r or c) continue,
            .JMP => if (insConditions == 0) @breakpoint()
        }
        
        const src: u64 = switch (instruction.task.fetch) {
            .MEMORY => self.memory[self.registers[dest]],
            .NONE => 0,
            .REGISTER => self.registers[dest],
            .VALUE => dest,
        };
        const val: u64 = switch (instruction.task.fetch) {
            .MEMORY => self.memory[self.registers[source]],
            .NONE => 0,
            .REGISTER => self.registers[source],
            .VALUE => source,
        };
        //Execute
        switch (instruction.task.operation) {
            .ADD => {
                self.registers[dest] += val;
            },
            .AND => {
                self.registers[dest] &= val;
            },
            .BSF => {
                self.registers[dest] = @ctz(val);
            },
            .BSR => {
                self.registers[dest] = @clz(val);
            },
            .BTS => {
                const truth = self.registers[dest] >> @intCast(val) & 1 == 1;
                flags.carry = truth;
                if (!truth) {
                    self.registers[dest] |= std.math.shl(u64, 1, val);
                }
            },
            .BTR => {
                const truth = self.registers[dest] >> @intCast(val) & 1 == 1;
                flags.carry = truth;
                if (!truth) {
                    self.registers[dest] &= ~(std.math.shl(u64, 1, val));
                }
            },
            .CALL => {
                const offset = self.registers[SP];
                self.registers[offset] = self.pc;
                self.registers[SP] -= 1;
                self.pc = dest;
                return;
            },
            .CMP => {
                flags.equal = self.registers[dest] == val;
                flags.greater = self.registers[dest] > val;
                flags.lower = self.registers[dest] < val;
            },
            .DEC => {
                self.registers[dest] -= 1;
            },
            .DIV => {
                self.registers[dest] /= val;
            },
            .FADD => {
                const destF: f64 = @bitCast(self.registers[dest]);
                const valF: f64 = @bitCast(val);
                const result: f64 = destF + valF;
                self.registers[dest] = @bitCast(result);
            },
            .FDIV => {
                const destF: f64 = @bitCast(self.registers[dest]);
                const valF: f64 = @bitCast(val);
                const result = destF / valF;
                self.registers[dest] = @bitCast(result);
            },
            .FMUL => {
                const destF: f64 = @bitCast(self.registers[dest]);
                const valF: f64 = @bitCast(val);
                const result = destF * valF;
                self.registers[dest] = @bitCast(result);
            },
            .FSQRT => {
                const valF: f64 = @bitCast(val);
                const result: f64 = @sqrt(valF);
                self.registers[dest] = @bitCast(result);
            },
            .FSUB => {
                const destF: f64 = @bitCast(self.registers[dest]);
                const valF: f64 = @bitCast(val);
                const result = destF - valF;
                self.registers[dest] = @bitCast(result);
            },
            .FTI => {
                const valF: f64 = @bitCast(val);
                self.registers[dest] = @intFromFloat(valF);
            },
            .HLT => {
                return null;
            },
            .INC => {
                self.registers[dest] += 1;
            },
            .ITF => {
                const valF: f64 = @floatFromInt(val);
                self.registers[dest] = @bitCast(valF);
            },
            .JMP => {
                self.pc = src;
                return;
            },
            .MOV => {
                self.registers[dest] = val;
            },
            .MUL => {
                self.registers[dest] *= val;
            },
            .NOP => {},
            .OUT => {
                const handle = switch (@import("builtin").os.tag) {
                    .windows => std.os.windows.peb().ProcessParameters.hStdOutput,
                    else => @as(i32, @intCast(dest)),
                };
                const info = @typeInfo(Register);
                const writer = (std.fs.File{ .handle = handle }).writer();
                const intermediate: [@divExact(info.Int.bits, 8)]u8 = @bitCast(val);
                for (intermediate) |value| {
                    if (value == 0) break;
                    try writer.writeByte(value);
                }
            },
            .OR => {
                self.registers[dest] |= val;
            },
            .POP => {
                self.registers[SP] += 1;
                const offset = self.registers[SP];
                const top = self.registers[offset];
                self.registers[dest] = top;
            },
            .PUSH => {
                const offset = self.registers[SP];
                self.registers[offset] = src;
                self.registers[SP] -= 1;
            },
            .RET => {
                self.registers[SP] += 1;
                const offset = self.registers[SP];
                self.pc = self.registers[offset]+1;
                return;
            },
            .SL => {
                self.registers[dest] <<= @intCast(val);
            },
            .SPI => {
                self.registers[SP] = Stack;
                flags.stack = true;
            },
            .SQRT => {
                self.registers[dest] = std.math.sqrt(val);
            },
            .SR => {
                self.registers[dest] >>= @intCast(val);
            },
            .SUB => {
                self.registers[dest] -= val;
            },
            .TEST => {
                flags.zero = val == 0;
                const T = @TypeOf(val);
                const TBits = std.meta.Int(.unsigned, @typeInfo(T).Int.bits);
                flags.sign = @as(TBits, @bitCast(val)) >> (@bitSizeOf(T) - 1) != 0;
            },
            .SWAPE => {
                self.registers[dest] = @byteSwap(val);
            },
            .XCHG => {
                self.registers[dest] ^= val;
                switch (instruction.task.fetch) {
                    .MEMORY => self.memory[self.registers[source]] ^= self.registers[dest],
                    .REGISTER => self.registers[source] ^= self.registers[dest],
                    .VALUE => return error.CantStoreToImmediateValue,
                    .NONE => return error.CantExchangeWithNothing,
                }
                switch (instruction.task.fetch) {
                    .MEMORY => self.registers[dest] ^= self.memory[self.registers[source]],
                    .REGISTER => self.registers[dest] ^= self.registers[source],
                    .VALUE => self.registers[dest] ^= source,
                    .NONE => return error.CantExchangeWithNothing,
                }
            },
            .XOR => {
                self.registers[dest] ^= val;
            }
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
