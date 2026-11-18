tar ext :3333

monitor halt
load

#0xfffe00ec corresponds to startup.s:97. We want to instruct OpenOCD to install the hb,
#since GDB may attempt to access that location prematurely, causing a data abort
#(the access occurs before OCM remapping).
monitor bp 0xfffe00ec 4 hw

continue

monitor pld load 0 ../hardware/board-files/design_1_wrapper.bit

# Measurement clock override after ps7_init (IO PLL = 1800 MHz).
# Select one frequency below. The initial measurement uses 50 MHz.
monitor mww 0xF8000008 0xDF0D

# 50 MHz = 1800 / 6 / 6
# monitor mww 0xF8000170 0x00600600

# 100 MHz = 1800 / 6 / 3
# monitor mww 0xF8000170 0x00300600
# 150 MHz = 1800 / 6 / 2
# monitor mww 0xF8000170 0x00200600
# 200 MHz = 1800 / 3 / 3
monitor mww 0xF8000170 0x00300300

monitor mww 0xF8000004 0x767B
monitor mdw 0xF8000170 1

#remove 0xfffe00ec location hb
monitor rbp 0xFFFE00EC

restore picture.bin binary (uint8_t*)&_binary_picture_bin_start

continue
