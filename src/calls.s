_add
    addr 0x12, 0x13
    ret

.start
    spi
    movv 0x12, 42
    movv 0x13, 27
    callv _add
    outr 0x12, 0x1
    hlt