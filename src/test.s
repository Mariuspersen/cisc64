.start
MOVV	0x11, 12
MOVV    0x13, 3
MOVV	0x12, .loop
.loop
OUTR    0x11, 0x1
SUBR	0x11, 0x13
CMPV	0x11, 5
MOVVL	0x12, .loop2
JMPR	0x12
.loop2
OUTR    0x11, 0x1
ADDR	0x11, 0x13
CMPV	0x11, 16
MOVVEG	0x12, .end
JMPR	0x12
.end
OUTR    0x11, 0x1
HLT