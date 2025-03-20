%REG1 0x12
%REG2 0x13
%STDOUT 0x1
%STDIN 0x0
%NUMBER 512
%ARG1 0x10
%ARG2 0x11
%RET 0x9
%CHAR_ZERO 0x30
%CHAR_NINE 0x39


_isNumeric
    xorr %RET, %RET
    cmpv %ARG1, %CHAR_ZERO
    addveg %RET, 1
    cmpv %ARG1, %CHAR_NINE
    addvel %RET, 1
    ret

_intoNumber
    callv _isNumeric
    cmpv, %RET, 2
    addve, %ARG1,%CHAR_ZERO
    movr %RET, %ARG1
    ret

.start
    spi
    movv %REG1, 1
    movv %REG2, 6
    addr %REG1, %REG2
    movr %ARG1, %REG1
    callv _intoNumber
    outr %RET, %STDOUT
    hlt