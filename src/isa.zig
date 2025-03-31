const std = @import("std");

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
    BFS, // Bit Forward Scan(find first set bit)
    BRS, // Bit Reverse Scan(find last set bit)
    BT, // Bit Test
    BC, // Bit Clear
    BS, // Bit Set
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
        inline for (OPInfo.@"enum".fields) |field| {
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
                std.debug.print("{c} is not a valid flag, ignoring...\n{s}\n", .{c,text});
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