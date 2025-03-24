.data
    HELLO 0x21646c726F57
    WORLD 0x206f6c6c6548

%STDOUT 0x1
%STDIN 0x0
%REG1 0x0

.hello
    xorr %REG1, %REG1
    inc %REG1
    outm %STDOUT, %REG1
    decr %REG1
    outm %STDOUT, %REG1
    ret
.start
    spi
    call .hello
    hlt
    hlt