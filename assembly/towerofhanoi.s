%NUM_DISK 0
%SRC_PEG 1
%DEST_PEG 2
%AUX_PEG 3
%JMP_REG 4
%LSB 5
%TEMP 6

.start
    spi
    movi %NUM_DISK, 2
    movi %SRC_PEG, 0b011
    movi %DEST_PEG, 0b000
    movi %AUX_PEG, 0b000
    calli .hanoi
    hlt

.hanoi
    cmpi %NUM_DISK, 1
    movi %JMP_REG, .not_one
    moviel %JMP_REG, .move_disk
    jmpr %JMP_REG
.not_one
    movi %AUX_PEG, 6
    subr %AUX_PEG, %SRC_PEG
    subr %AUX_PEG, %DEST_PEG
    pushr %AUX_PEG
    pushr %SRC_PEG
    pushr %DEST_PEG

    decr %NUM_DISK
    calli .hanoi

.move_disk
    bfsr %LSB, %SRC_PEG
    bc %SRC_PEG, %LSB
    bfsr %LSB, %DEST_PEG
    bs %DEST_PEG, %LSB
    ret