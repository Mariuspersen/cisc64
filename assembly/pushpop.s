%STDOUT 0x1
%STDIN 0x0
%REG1 0x0

.start
spi
movv    0x10, 0x41
movv    0x11, 0x42
cmpr    0x11, 0x10
outre    %STDOUT, 0x10
pushr   0x10
outr    %STDOUT, 0x11
popr    0x11
outr    %STDOUT, 0x11
hlt