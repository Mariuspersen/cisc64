.data
    YES 0x736559
    NO 0x6F4E

%REG1 0x0
%REG2 0x1
%STDOUT 0x1
%STDIN 0x0

.isDigit
    movi %REG2, 1
    cmpi %REG1, 0x30
    movieg %REG2, 0
    cmpi %REG1, 0x3A
    movieg %REG2, 1
    ret
.start
    spi
    ini %STDIN, %REG1
    nop
    calli .isDigit
    outf %REG2, %STDOUT
    hlt