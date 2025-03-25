.data
    HELLO 0x21646c726F57
    WORLD 0x206f6c6c6548
    POLICE 0x52434946464F

%STDOUT 0x1
%STDIN 0x0
%REG1 0x0
%REG2 0x1

.hello
    xorr %REG1, %REG1
    xorr %REG2, %REG2
    addi %REG2, 2
    movf %REG2, %REG2
    movt %REG1, %REG2
    inc %REG1
    outf %STDOUT, %REG1
    decr %REG1
    outf %STDOUT, %REG1
    ret
.start
    spi
    call .hello
    hlt
    hlt