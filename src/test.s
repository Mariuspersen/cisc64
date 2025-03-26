%STDOUT 0x1
%STDIN 0x0
%REG1 0x0
%REG2 0x1

.loop
    incr %REG1
    cmpi %REG1 0x7E
    outr %STDOUT, %REG1
    reteg
    jmpr %REG2
.start
    spi
    movi %REG1 0x20
    movi %REG2 .loop
    callr %REG2
    outi %STDOUT, 0xA
    hlt