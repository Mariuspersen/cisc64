%REG1 0x12
%REG2 0x13
%STDOUT 0x1
%STDIN 0x0
%NUMBER 512
%ARG1 0x10
%ARG2 0x11
%RET 0x9

_isDigit
    xorr %RET, %RET
    cmpv %ARG1, 9
    addvel %RET, 1
    ret

_intoChar
    callv _isDigit
    cmpv, %RET, 1
    addve, %ARG1,0x30
    movr %RET, %ARG1
    ret

.start
    spi
    movv %ARG1, 72
    callv _intoChar
    outr %RET, %STDOUT
    hlt