# Thought experiment on a new type of architecture

**NOTE: I'm not a CPU Architecture designer and this should not be taken seriously**

Current Idea: EPIC Type ISA 32-Bit fixed instruction size with No Conditional Jumps

- a 8-bit addressable space of 64-bit Registers
- 64-bit fetch of two 32-bit instructions, fed into two pipelines
- Each instruction has a conditional, will not execute if appropriate flag is not set
- The instruction will still execute if none of the instruction flags are set
- Only exception is any instruction modifying the program counter (JMP, CALL, RTS, etc)
- Each instruction has a fetch type, REGISTER, TO_MEMORY, FROM_MEMORY, IMMEDIATE,
- REGISTER will use the right hand value as a address to a register value
- TO_MEMORY will use the left hand value as address to a register containing a pointer into memory
- FROM_MEMORY will use right hand value as address to a register containing a pointer into memory
- IMMEDIATE will be interpreted as a value
- 32bit and 64bit immediate loads are possible through LI32 and LI64 instructions
