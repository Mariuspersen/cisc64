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

pub const Instruction = enum(u16) {
    HLT,    
    MOVV,   //MOVV(Load Value into Register), 0xFF(Register Address), 0xFFFFFFFFFFFFFFFF(Value 64-Bit)
    MOVR,   //MOVR(Load Register into Register), 0xFF(dest), 0xFF(source)
    JMPV,   //JMPV(Jump with Value), 0xFFFFFFFFFFFFFFFF(Value 64-Bit)
    JMPR,   //JMPR(Jump with Register), 0xFF(Set PC to value in register)
    MOVNZ,  //MOVNZ(Move If Not Zero), 0xFF(dest), 0xFF(source)
    MOVZ,   //MOVNZ(Move If Zero), 0xFF(dest), 0xFF(source)
    INCRNZ, //INCRNZ(Increment Register if Not Zero), 0xFF(Register)
    DECRNZ, //DECRNZ(Decrement Register if Not Zero), 0xFF(Register)
    INCRZ,  //INCRZ(Increment Register if Zero), 0xFF(Register)
    DECRZ,  //DECRZ(Decrement Register if Zero), 0xFF(Register)
    SUBV,   //SUBV(Subtract value from register), 0xFF(Register Address), 0xFFFFFFFFFFFFFFFF(Value 64-Bit)
    SUBR,   //SUBR(Subtract register from register), 0xFF(Register Address), 0xFF(Register Address)
    CTLE,   //TLE(Cast to little endian), 0xFF(Register Address)
    CTBE,   //TLE(Cast to big endian), 0xFF(Register Address) 
    
    ADDV = 0x090D,  //0x0906(Add value from register), 0xFF(Register Address), 0xFFFFFFFFFFFFFFFF(Value 64-Bit)
    ADDR = 0x020E,  //0x0906(Add register from register), 0xFF(Register Address), 0xFF(Register Address)

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

fn fetchNext(self: *Self, T: type) T {
    const addr = sliceToType(self.program[self.pc..], T);
    self.pc += @sizeOf(T);
    return addr;
}

pub fn fetchExecuteInstruction(self: *Self) void {
    const ins = Instruction.fetch(self.program[self.pc..]);
    self.pc += @sizeOf(@TypeOf(ins));
    std.debug.print("{any}\n", .{ins});
    switch (ins) {
        .HLT => @panic("HALTED!"),
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
            if(self.registers[addr] != 0) {
                self.registers[addr] += 1;
            }
        },
        .JMPV => {
            const value = self.fetchNext(u64);
            self.pc = value;
        },
        .JMPR => {
            const addr = self.fetchNext(u8);
            self.pc = self.registers[addr];
        },
        else => @panic("Using unimplemented instruction!")
    }
}
