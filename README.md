# Thought experiment on a new type of architecture

Current Idea: EPIC Type ISA 32-Bit fixed instruction size with No Conditional Jumps

- a 8-bit addressable space of 64-bit Registers
- 64-bit fetch of two 32-bit instructions, fed into two pipelines
- Each instruction has a conditional, will not execute if appropriate flag is not set
- Only exception is jumps, any jump with a conditional will be ignored
- Each instruction has a load type, None, Memory, Register, Value.
- None loads nothing, some instructions also dont take arguments,
- Memory means it will use the 64-bit value in the register address as a pointer into memory
- Register means it will use the 64-bit value from the register directly
- Value means it will intepret the 8-bit address as a value

I'm not a CPU Architecture designer and this should not be taken seriously