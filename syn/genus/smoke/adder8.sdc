create_clock -name clk -period 5.0 [get_ports clk]
set_input_delay  -clock clk 0.5 [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -clock clk 0.5 [all_outputs]
