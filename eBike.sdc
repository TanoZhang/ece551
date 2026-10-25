# 50 MHz system clock from the DE0-Nano oscillator
create_clock -name clk -period 20.000 [get_ports clk]
derive_clock_uncertainty

# Push buttons, Hall sensors, cadence and the SPI/IMU inputs are asynchronous
# and are double-flopped inside the design
set_false_path -from [get_ports {RST_n tgglMd cadence hallGrn hallYlw hallBlu inertINT inertMISO A2D_MISO}]

# Outputs drive slow off-chip loads (gate drivers, SPI slaves, UART)
set_false_path -to [get_ports {highGrn lowGrn highYlw lowYlw highBlu lowBlu A2D_SS_n A2D_SCLK A2D_MOSI inertSS_n inertSCLK inertMOSI TX LED[*]}]
