%REG1 0x12
%REG2 0x13
%STDOUT 0x1
%STDIN 0x0
%NUMBER 512

_add
    addr %REG1, %REG2
    ret

.start
    spi
    movv %REG1, %NUMBER
    movv %REG2, 27
    callv _add
    outr %REG1, %STDOUT
    hlt