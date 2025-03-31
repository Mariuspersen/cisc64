%STDOUT 0x1
%STDIN 0x0
%REG1 0x2
%REG2 0x3

.hello
    nop
    li64r %REG2
    0x6F57206f6c6c6548
    li64r %REG1
    0xA21646c72
    outr %STDOUT, %REG2
    outr %STDOUT, %REG1
    ret
.start
    spi
    calli .hello
    hlt