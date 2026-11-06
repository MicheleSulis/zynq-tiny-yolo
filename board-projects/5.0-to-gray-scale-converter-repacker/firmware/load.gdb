tar ext :3333

monitor halt
load

#0xfffe00ec corresponds to startup.s:97. We want to instruct OpenOCD to install the hb,
#since GDB may attempt to access that location prematurely, causing a data abort
#(the access occurs before OCM remapping).
monitor bp 0xfffe00ec 4 hw

continue

monitor pld load 0 design_1_wrapper.bit

#remove 0xfffe00ec location hb
monitor rbp 0xFFFE00EC

hb zynq.c:156
restore picture.bin binary (uint8_t*)_binary_picture_bin_start

continue
