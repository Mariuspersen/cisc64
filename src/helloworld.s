%HELLO 0x21646c726F57
%WORLD 0x206f6c6c6548

%REG1 0x4
%REG2 0x5

%STDOUT 0x1
%STDIN 0x0

.start
    movv %REG1, %HELLO
    movv %REG2, %WORLD
    outr %REG2, %STDOUT
    outr %REG1, %STDOUT
    hlt