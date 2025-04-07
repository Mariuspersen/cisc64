const std = @import("std");

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
    SPI, //Stack Pointer Init
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
    operation: OP, //What actually is being executed
    fetch: FT, //Fetch type, value,register,memory
};

pub const JumpImmediate = packed struct {
    operation: OP,
    dest: u26
};

pub const NoFetchConditionalTwoArg = packed struct {
    operation: OP,
    condition: Conditional,
    dest: u8,
    src: u10,
};

pub const NoFetchConditionalOneArg = packed struct {
    operation: OP,
    condition: Conditional,
    dest: u18,
};

pub const NoFetchNoConditionalTwoArg = packed struct {
    operation: OP,
    dest: u8,
    src: u18,
};

pub const NoFetchNoConditionalOneArg = packed struct {
    operation: OP,
    dest: u26,
};

pub const FetchNoConditionalTwoArg = packed struct {
    operation: OP,
    fetch: FT,
    dest: u8,
    src: u16,
};

pub const FetchNoConditionalOneArg = packed struct {
    operation: OP,
    fetch: FT,
    dest: u24,
};

pub const FetchConditionalOneArg = packed struct {
    operation: OP,
    fetch: FT,
    condition: Conditional,
    dest: u16,
};

pub const FetchConditionalTwoArg = packed struct {
    operation: OP,
    fetch: FT,
    condition: Conditional,
    dest: u8,
    src: u8,
};

comptime {
    if (@bitSizeOf(FetchConditionalOneArg) != 32) @compileError("Not correct instruction size");
    if (@bitSizeOf(FetchConditionalTwoArg) != 32) @compileError("Not correct instruction size");
    if (@bitSizeOf(FetchNoConditionalOneArg) != 32) @compileError("Not correct instruction size");
    if (@bitSizeOf(FetchNoConditionalTwoArg) != 32) @compileError("Not correct instruction size");
    if (@bitSizeOf(NoFetchNoConditionalOneArg) != 32) @compileError("Not correct instruction size");
    if (@bitSizeOf(NoFetchNoConditionalTwoArg) != 32) @compileError("Not correct instruction size");
    if (@bitSizeOf(NoFetchConditionalOneArg) != 32) @compileError("Not correct instruction size");
    if (@bitSizeOf(NoFetchConditionalTwoArg) != 32) @compileError("Not correct instruction size");

}

const _Instruction = packed union {
    jump: JumpImmediate,
    fcoa: FetchConditionalOneArg,
    fcta: FetchConditionalTwoArg,
    fncoa: FetchNoConditionalOneArg,
    fncta: FetchNoConditionalTwoArg,
    nfcoa: NoFetchConditionalOneArg,
    nfcta: NoFetchConditionalTwoArg,
    nfncoa: NoFetchNoConditionalOneArg,
    nfncta: NoFetchNoConditionalTwoArg,

    pub fn fromToken(text: []const u8, dest: u26, source: ?u18) !_Instruction {
        var operation: OP = .NOP;
        var fetch: ?FT = null;
        var condition: ?Conditional = null;
        var OTLen: usize = 0;
        inline for (@typeInfo(OP).@"enum".fields) |field| {
            if (std.ascii.startsWithIgnoreCase(text, field.name)) {
                operation = @field(OP, field.name);
                OTLen = field.name.len;
            }
        }
        if (OTLen == 0) return error.InvalidInstruction;
        fetch = switch (text[OTLen]) {
            'T', 't' => .TO_MEMORY,
            'F', 'f' => .FROM_MEMORY,
            'R', 'r' => .REGISTER,
            'I', 'i' => .IMMEDIATE,
            else => blk: {
                OTLen -= 1;
                break :blk null;
            },
        };
        OTLen += 1;
        switch (operation) {
            .CALL, .RET, .JMP => {
                if (text.len != OTLen) {
                    std.debug.print("Instructions that modify program counter cannot have conditionals!\n", .{});
                    return error.ConditionalOnJump;
                }
            },
            else => {}
        }
        for (text[OTLen..]) |c| switch (c) {
            'Z', 'z' => condition.zero = true,
            'E', 'e' => condition.equal = true,
            'G', 'g' => condition.greater = true,
            'L', 'l' => condition.lower = true,
            'C', 'c' => condition.carry = true,
            'S', 's' => condition.sign = true,
            'O', 'o' => condition.overflow = true,
            'P', 'p' => condition.parity = true,
            else => {
                std.debug.print("{c} is not a valid flag, ignoring...\n{s}\n", .{c,text});
            },
        };
        switch (operation) {
            .JMP, .CALL => {
                return .{
                    .jump = .{
                        .operation = operation,
                        .dest = dest,
                    }
                };
            },
            else => {
                if (fetch) |f| {
                    if (condition) |c| {
                        if (source) |s| {
                            return .{
                                .fcta = .{
                                    .operation = operation,
                                    .fetch = f,
                                    .condition = c,
                                    .dest = @intCast(dest),
                                    .src = @intCast(s),
                                }
                            };
                        } else {
                             return .{
                                .fcoa = .{
                                    .operation = operation,
                                    .fetch = f,
                                    .condition = c,
                                    .dest = @intCast(dest),
                                }
                            };
                        }
                    } else {
                        if (source) |s| {
                            return .{
                                .fncta = .{
                                    .operation = operation,
                                    .fetch = f,
                                    .dest = @intCast(dest),
                                    .src = @intCast(s),
                                }
                            };
                        }
                        else {
                            return .{
                                .fncoa = .{
                                    .operation = operation,
                                    .fetch = f,
                                    .dest = @intCast(dest),
                                }
                            };
                        }
                    }
                } else {
                    if (condition) |c| {
                        if (source) |s| {
                            return .{
                                .nfcta = .{
                                    .operation = operation,
                                    .condition = c,
                                    .dest = @intCast(dest),
                                    .src = @intCast(s),
                                }
                            };
                        } else {
                             return .{
                                .nfcoa = .{
                                    .operation = operation,
                                    .condition = c,
                                    .dest = @intCast(dest),
                                }
                            };
                        }
                    } else {
                        if (source) |s| {
                            return .{
                                .nfncta = .{
                                    .operation = operation,
                                    .dest = @intCast(dest),
                                    .src = @intCast(s),
                                }
                            };
                        }
                        else {
                            return .{
                                .nfncoa = .{
                                    .operation = operation,
                                    .dest = @intCast(dest),
                                }
                            };
                        }
                    }
                }
            }
        }
    }
};

pub const Instruction = packed struct {
    task: Task,
    condition: Conditional,
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