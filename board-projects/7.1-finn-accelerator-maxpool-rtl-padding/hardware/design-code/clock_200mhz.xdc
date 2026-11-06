create_clock -name clk_fpga_0 -period 5.000 -waveform {0.000 2.500} [get_pins -hierarchical -regexp {.*PS7_i/FCLKCLK\[0\]}]
