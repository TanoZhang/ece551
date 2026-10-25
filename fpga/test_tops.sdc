# 50 MHz DE0-Nano clock for the FPGA unit-test projects
create_clock -name clk -period 20.000 [get_ports clk]
derive_clock_uncertainty
