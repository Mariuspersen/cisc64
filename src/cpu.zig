const std = @import("std");
const testing = std.testing;
const Self = @This();

// THE IDEA //
// a CISC instruction set with no conditional jumps to tackle speculative execution attacks
// In recent times there as been a lot of attacks that target the branch predictor in modern CPU's to extract information
// The reason these sort of attacks are possible is because modern CPU's are pipelined ( I think )
// Reducing the need for flushing the pipeline, speculative execution and branch prediction is used
// This of course causes the above mention attacks

// What if we instead didnt have conditional jumps?
// We not longer need a branch predictor and speculative execution becomes just execution.


const Flag = u1;
const Register = u64;

const Opcode = enum(u8) {
    LDR = 0x01, //Load to register -> LDR $[address(1 byte)] value(4 bytes)
    LDF = 0x02, //Load to flag -> LDF $[address(1 byte)] value(1 bytes) NOTE: truncated, only first bit is taken
    ADDRV = 0x03, //Add value to register -> ADDRV $[address of result flag(1 byte)]  $[address of carry flag(1 byte)] value(4 bytes)
    ADDRR = 0x04, //Add register to register -> ADDRR $[address of result register(1 byte)] $[address value register(1 byte)] $[address of carry flag(1 byte)] 
    ADDRF = 0x05, //Add flag to register -> ADDRR $[address of result flag(1 byte)]  $[address of carry flag(1 byte)] $[address value register(1 byte)]
    SUBRV = 0x06, //Subtract value to register -> SUBRV $[address of result flag(1 byte)]  $[address of carry flag(1 byte)] value(4 bytes)
    SUBRR = 0x07, //Subtract register to register -> SUBRR $[address of result register(1 byte)] $[address value register(1 byte)] $[address of carry flag(1 byte)] 
    SUBRF = 0x08, //Subtract flag to register -> SUBRF $[address of result flag(1 byte)]  $[address of carry flag(1 byte)] $[address value register(1 byte)]
    MOVNZ = 0x09, //Move if not zero -> MOVNZ $[address of register(1 byte)] $[address of not zero flag(1 byte)] $[address of register(1 byte)]
    MOVZ = 0x0A, //Move if zero -> MOVZ $[address of register(1 byte)] $[address of zero flag(1 byte)] $[address of register(1 byte)]
    SHFTL = 0x0B, //Shift left -> SHFTL $[address of register(1 byte)]
    SHFTR = 0x0C, //Shift right -> SHFTR $[address of register(1 byte)]
    TERN = 0x0D, //Ternary, TERN $[address of result register(1 byte)]  $[address of bool flag(1 byte)] $[address of option(1 byte)] $[address of option(1 byte)]


};

program_counter: u64 = 0,
registers: [std.math.maxInt(u8)]Register,
flags: [std.math.maxInt(u8)]Flag,
