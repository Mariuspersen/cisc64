.start
spi
movv    0x10, 1337
outr    0x10, 0x1
pushr   0x10
outr    0x11, 0x1
popr    0x11
outr    0x11, 0x1
hlt