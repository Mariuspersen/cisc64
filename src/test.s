%STDOUT 0x1
%STDIN 0x0
%REG1 0x0
%REG2 0x1


.loop
    incr %REG1
    cmpv %REG1 0x7E
    movveg %REG2, .end
    outr %STDOUT, %REG1
    jmpr %REG2
    nop
.end
    hlt
    hlt
.start
    spi
    movv %REG1 0x21
    movv %REG2 .loop
    jmpr %REG2