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
const FLAGS_ADDR = 0x01;
const SP = 0xFE;
const Stack = 0xFD;

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
    HLT,
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
};

const Task = packed struct {
    fetch: FT, //Fetch type, value,register,memory
    operation: OP, //What actually is being executed
};

const _Instruction = packed struct {
    condition: Conditional,
    task: Task,
    destination: u8,
    source: u8,

    pub fn fromToken(text: []const u8, dest: u8, source: u8) !_Instruction {
        const OPInfo = @typeInfo(OP);
        var ins = std.mem.zeroInit(_Instruction, .{});
        ins.destination = dest;
        ins.source = source;
        var OTLen: usize = 0;
        inline for (OPInfo.Enum.fields) |field| {
            if (std.mem.startsWith(u8, text, field.name)) {
                ins.task.operation = @field(OP, field.name);
                OTLen = field.name.len;
            }
        }
        if (OTLen == 0) return error.InvalidInstruction;
        if (text.len == OTLen) return ins;
        ins.task.fetch = switch (text[OTLen]) {
            'N' => .NONE,
            'M' => .MEMORY,
            'R' => .REGISTER,
            'V' => .VALUE,
            else => blk: {
                OTLen -= 1;
                break :blk .NONE;
            },
        };
        OTLen += 1;
        for (text[OTLen..]) |c| switch (c) {
            'Z' => ins.condition.zero = true,
            'E' => ins.condition.equal = true,
            'G' => ins.condition.greater = true,
            'L' => ins.condition.lower = true,
            'C' => ins.condition.carry = true,
            'S' => ins.condition.sign = true,
            'O' => ins.condition.overflow = true,
            'P' => ins.condition.parity = true,
            else => return error.InvalidConditionalFlag,
        };

        return ins;
    }

    pub fn fetch(value: u64) [2]_Instruction {
        return @bitCast(value);
    }

    pub fn toString(self: *const _Instruction) [@sizeOf(_Instruction)]u8 {
        return @bitCast(self.*);
    }
};

test "InstructionAssemblerToBytes" {
    const ins = try _Instruction.fromToken("HLTVZEGLCSO", 0, 0);
    std.debug.print("{X}\n", .{ins.toString()});
}

test "fetchInstructionsFromMemory" {
    const ins1 = try _Instruction.fromToken("HLTVZEGLCSO", 0, 0);
    const ins2 = try _Instruction.fromToken("NOP", 0, 0);
    const doubleins = ins1.toString() ++ ins2.toString();
    const memory: u64 = @bitCast(doubleins);
    std.debug.print("{any}\n", .{_Instruction.fetch(memory)});
}

fn fetchDecodeExecute(self: *Self) !?void {
    //Fetch
    const bundle = _Instruction.fetch(self.memory[self.pc]);
    var flags: *FLAGSR = @ptrCast(&self.registers[FLAGS_ADDR]);
    _ = &flags;
    //Decode
    for (bundle) |instruction| {
        const dest = instruction.destination;
        const source = instruction.source;
        const flagConditions: u8 = @truncate(self.registers[FLAGS_ADDR]);
        const insConditions: u8 = @bitCast(instruction.condition);
        if (flagConditions & insConditions == 0 and insConditions != 0) continue;
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
                self.pc = val;
                const offset = self.registers[SP];
                self.registers[offset] = val;
                self.registers[SP] -= 1;
            },
            .CMP => {
                flags.equal = self.registers[dest] == val;
                flags.greater = self.registers[dest] < val;
                flags.lower = self.registers[dest] > val;
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
                self.pc = self.registers[val];
            },
            .MOV => {
                self.registers[dest] = val;
            },
            .MUL => {
                self.registers[dest] *= val;
            },
            .NOP => {},
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
                self.registers[offset] = val;
                self.registers[SP] -= 1;
            },
            .RET => {
                self.registers[SP] += 1;
                const offset = self.registers[SP];
                self.pc = self.registers[offset];
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
            else => return error.NotYetImplemented,
        }
    }
}

test "newFetch" {
    var cpu = Self.init("");
    const ins1 = try _Instruction.fromToken("ITFV", 0, 7);
    const ins2 = try _Instruction.fromToken("FADDR", 0, 0);
    const doubleins = ins1.toString() ++ ins2.toString();
    cpu.memory[0] = @bitCast(doubleins);
    _ = try cpu.fetchDecodeExecute();
    std.debug.print("{d}\n", .{@as(f64, @bitCast(cpu.registers[0]))});
}

//With this you can basically make arbitrary instructions
//I'm sure NOPNZEGLCSO (No Operation with no fetching if Zero, Equal, Greater, Lower, Carry, Sign or Overflow flag is set) will be very useful

pub const Instruction = enum(u16) {
    HLT,
    MOVV, //MOVV(Load Value into Register), 0xFF(Register Address), 0xFFFFFFFFFFFFFFFF(Value 64-Bit)
    MOVR, //MOVR(Load Register into Register), 0xFF(dest), 0xFF(source)
    JMPV, //JMPV(Jump with Value), 0xFFFFFFFFFFFFFFFF(Value 64-Bit)
    JMPR, //JMPR(Jump with Register), 0xFF(Set PC to value in register)
    MOVVNZ, //MOVVNZ(Move value If Not Zero), 0xFF(dest), 0xFF(source)
    MOVVZ, //MOVVNZ(Move value If Zero), 0xFF(dest), 0xFF(source)
    MOVRNZ, //MOVVNZ(Move register If Not Zero), 0xFF(dest), 0xFF(source)
    MOVRZ, //MOVVNZ(Move register If Zero), 0xFF(dest), 0xFF(source)
    MOVVEG, //MOVVEG(Move value if Flags EQL or Greater is set)
    MOVVEL, //MOVVEG(Move value if Flags EQL or LWR is set)
    MOVVL, //MOVVL(Move value if Flags LWR is set)
    CMPR, //CMPR(Compare Register to Register)
    CMPV, //CMPV(Compare Register to value)
    DECR, //DECR(Decrement register), 0xFF(Register)
    INCRNZ, //INCRNZ(Increment Register if Not Zero), 0xFF(Register)
    DECRNZ, //DECRNZ(Decrement Register if Not Zero), 0xFF(Register)
    INCRZ, //INCRZ(Increment Register if Zero), 0xFF(Register)
    INCR, //INCRZ(Increment Register), 0xFF(Register)
    DECRZ, //DECRZ(Decrement Register if Zero), 0xFF(Register)
    SUBV, //SUBV(Subtract value from register), 0xFF(Register Address), 0xFFFFFFFFFFFFFFFF(Value 64-Bit)
    SUBR, //SUBR(Subtract register from register), 0xFF(Register Address), 0xFF(Register Address)
    CTLE, //TLE(Cast to little endian), 0xFF(Register Address)
    CTBE, //TLE(Cast to big endian), 0xFF(Register Address),
    TESTR, //TEST(Tests a register, fills the flags register), 0xFF(Register)

    ADDV, //0x0906(Add value from register), 0xFF(Register Address), 0xFFFFFFFFFFFFFFFF(Value 64-Bit)
    ADDR, //0x0906(Add register from register), 0xFF(Register Address), 0xFF(Register Address)
    OUTR, //Out register 0xFF(Register Address) 0xFF(Port(File Descriptor basically))
    CALLR,
    CALLV,
    RET,
    PUSHR,
    POPR,
    SPI, //SPI - Stack Pointer Init, sets Stack flag
    MOVFM, //MOVM(Move value from memory) 0xFF(Register Address), 0xFFFFFFFFFFFFFFFF(Memory Address)
    MOVTM, //MOVM(Move value to memory) 0xFF(Register Address), 0xFFFFFFFFFFFFFFFF(Memory Address)
    ADDVEL, //ADDVEL(Add Value if Flags EQL or LWR is set)
    ADDVEG, //ADDVEL(Add Value if Flags EQL or GTR is set)
    ADDVE, //ADDVE(Add Value if Flags EQL is set)
    XORR, //XOR Registers, you know what this does

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
        else => @compileError("Stop doing weird things!"),
    };
    const intermediate: *[@divExact(len, 8)]u8 = @constCast(@ptrCast(program.ptr));
    const val: T = @bitCast(intermediate.*);
    return val;
}

pc: u64 = 0,
registers: [std.math.maxInt(u8)]Register,
program: []const u8,
memory: [1024]u64 = undefined,

pub fn init(program: []const u8) Self {
    return .{
        .pc = 0,
        .registers = std.mem.zeroes([std.math.maxInt(u8)]Register),
        .program = program,
    };
}

fn fetchNext(self: *Self, T: type) T {
    const addr = sliceToType(self.program[self.pc..], T);
    self.pc += @sizeOf(T);
    return addr;
}

pub fn fetchExecuteInstruction(self: *Self) !?void {
    var flags: *FLAGSR = @ptrCast(&self.registers[FLAGS_ADDR]);
    const ins = Instruction.fetch(self.program[self.pc..]);
    self.pc += @sizeOf(@TypeOf(ins));
    errdefer {
        std.debug.print("Instruction {any} Program Counter: 0x{X}\n", .{ ins, self.pc });
    }
    switch (ins) {
        .HLT => return null,
        .MOVV => {
            const addr = self.fetchNext(u8);
            const value = self.fetchNext(u64);
            self.registers[addr] = value;
        },
        .MOVR => {
            const addr1 = self.fetchNext(u8);
            const addr2 = self.fetchNext(u8);
            self.registers[addr1] = self.registers[addr2];
        },
        .INCRNZ => {
            const addr = self.fetchNext(u8);
            if (self.registers[addr] != 0) {
                self.registers[addr] += 1;
            }
        },
        .INCR => {
            const addr = self.fetchNext(u8);
            self.registers[addr] += 1;
        },
        .DECR => {
            const addr = self.fetchNext(u8);
            self.registers[addr] -= 1;
        },
        .SUBR => {
            const addr1 = self.fetchNext(u8);
            const addr2 = self.fetchNext(u8);
            self.registers[addr1] -= self.registers[addr2];
        },
        .XORR => {
            const addr1 = self.fetchNext(u8);
            const addr2 = self.fetchNext(u8);
            self.registers[addr1] ^= self.registers[addr2];
        },
        .ADDR => {
            const addr1 = self.fetchNext(u8);
            const addr2 = self.fetchNext(u8);
            self.registers[addr1] += self.registers[addr2];
        },
        .JMPV => {
            const value = self.fetchNext(u64);
            self.pc = value;
        },
        .JMPR => {
            const addr = self.fetchNext(u8);
            self.pc = self.registers[addr];
        },
        .CMPR => {
            const addr1 = self.fetchNext(u8);
            const addr2 = self.fetchNext(u8);
            flags.equal = self.registers[addr1] == self.registers[addr2];
            flags.greater = self.registers[addr1] < self.registers[addr2];
            flags.lower = self.registers[addr1] > self.registers[addr2];
        },
        .CMPV => {
            const addr = self.fetchNext(u8);
            const value = self.fetchNext(u64);
            flags.equal = self.registers[addr] == value;
            flags.greater = self.registers[addr] > value;
            flags.lower = self.registers[addr] < value;
        },
        .MOVVEG => {
            const addr = self.fetchNext(u8);
            const value = self.fetchNext(u64);
            if (flags.equal or flags.greater) {
                self.registers[addr] = value;
            }
        },
        .ADDVEL => {
            const addr = self.fetchNext(u8);
            const value = self.fetchNext(u64);
            if (flags.equal or flags.lower) {
                self.registers[addr] += value;
            }
        },
        .ADDVEG => {
            const addr = self.fetchNext(u8);
            const value = self.fetchNext(u64);
            if (flags.equal or flags.greater) {
                self.registers[addr] += value;
            }
        },
        .ADDVE => {
            const addr = self.fetchNext(u8);
            const value = self.fetchNext(u64);
            if (flags.equal) {
                self.registers[addr] += value;
            }
        },
        .MOVVL => {
            const addr = self.fetchNext(u8);
            const value = self.fetchNext(u64);
            if (flags.lower) {
                self.registers[addr] = value;
            }
        },
        .TESTR => {
            const addr = self.fetchNext(u8);
            flags.zero = self.registers[addr] == 0;
            const T = @TypeOf(self.registers[addr]);
            const TBits = std.meta.Int(.unsigned, @typeInfo(T).Int.bits);
            flags.sign = @as(TBits, @bitCast(self.registers[addr])) >> (@bitSizeOf(T) - 1) != 0;
        },
        .MOVVZ => {
            const addr = self.fetchNext(u8);
            const value = self.fetchNext(u64);
            if (flags.zero) {
                self.registers[addr] = value;
            }
            flags.zero = false;
        },
        .OUTR => {
            const addr = self.fetchNext(u8);
            const port = self.fetchNext(u8);
            const val = self.registers[addr];
            const handle = switch (@import("builtin").os.tag) {
                .windows => std.os.windows.peb().ProcessParameters.hStdOutput,
                else => @as(i32, @intCast(port)),
            };
            const info = @typeInfo(Register);
            const writer = (std.fs.File{ .handle = handle }).writer();
            const intermediate: [@divExact(info.Int.bits, 8)]u8 = @bitCast(val);
            for (intermediate) |value| {
                if (value == 0) break;
                try writer.writeByte(value);
            }

            //writer.print("{d} ", .{self.registers[addr]}) catch {};
        },
        .SPI => {
            self.registers[SP] = Stack;
            flags.stack = true;
        },
        .PUSHR => {
            const addr = self.fetchNext(u8);
            const val = self.registers[addr];
            const offset = self.registers[SP];
            self.registers[offset] = val;
            self.registers[SP] -= 1;
        },
        .POPR => {
            self.registers[SP] += 1;
            const addr = self.fetchNext(u8);
            const offset = self.registers[SP];
            const val = self.registers[offset];
            self.registers[addr] = val;
        },
        .CALLR => {
            const addr = self.fetchNext(u8);
            const val = self.registers[addr];
            self.pc = val;
            const offset = self.registers[SP];
            self.registers[offset] = val;
            self.registers[SP] -= 1;
        },
        .CALLV => {
            const offset = self.registers[SP];
            const val = self.fetchNext(u64);
            self.registers[offset] = self.pc;
            self.registers[SP] -= 1;
            self.pc = val;
        },
        .RET => {
            self.registers[SP] += 1;
            const offset = self.registers[SP];
            self.pc = self.registers[offset];
        },
        else => return error.NotYetImplemented,
    }
}
