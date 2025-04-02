%NUM_DISK 0
%SRC_PEG 1
%DEST_PEG 2
%AUX_PEG 3
%JMP_REG 4
%LSB 5
%TEMP 6

.start
    movi %NUM_DISK, 2
    movi %SRC_PEG, 0b11
    movi %DEST_PEG, 0b00
    movi %AUX_PEG, 0b00

    pushr %NUM_DISK
    pushr %SRC_PEG
    pushr %DEST_PEG
    pushr %AUX_PEG
    calli .hanoi

.hanoi
    popr %JMP_REG
    popr %AUX_PEG
    popr %DEST_PEG
    popr %SRC_PEG
    popr %NUM_DISK
    pushr %JMP_REG

    testr %NUM_DISK
    movi %JMP_REG, .not_last
    moviz %JMP_REG, .last_disk
.not_last
    decr %NUM_DISK
    pushr %NUM_DISK
    pushr %SRC_PEG
    pushr %AUX_PEG
    pushr %DEST_PEG

    calli .hanoi
    calli .move_disk

    pushr %NUM_DISK
    pushr %DEST_PEG
    pushr %SRC_PEG
    pushr %AUX_PEG
    calli .hanoi

.last_disk
    popr %AUX_PEG
    popr %DEST_PEG
    popr %SRC_PEG
    popr %NUM_DISK
    ret

.move_disk
    bfsr %LSB, %SRC_PEG
    bcr  %SRC_PEG, %LSB
    bfsr %LSB, %DEST_PEG
    bsr  %DEST_PEG, %LSB 