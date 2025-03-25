%STDOUT 0x1
%STDIN 0x0
%REG1 0x0
%REG2 0x1

.loop
    incr %REG1
    cmpi %REG1 0x7E
    movieg %REG2, .end
    outr %STDOUT, %REG1
    jmpr %REG2
    nop
.end
    hlt
    hlt
.start
    spi
    movi %REG1 0x21
    movi %REG2 .loop
    jmpr %REG2