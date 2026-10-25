# eBike ASIC synthesis constraints (template; run_genus.sh fills in
# @PERIOD@ in ns and @LOAD@ in the library's capacitance unit).
# Values follow the team's ECE 551 Design Compiler script (eBike.dc).

create_clock -name clk -period @PERIOD@ [get_ports clk]
set_clock_uncertainty 0.15 [get_clocks clk]

set_input_delay  -clock clk 0.3 [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -clock clk 0.5 [all_outputs]

set_driving_cell -lib_cell NAND2X1 [remove_from_collection [all_inputs] [get_ports clk]]
set_load @LOAD@ [all_outputs]

set_max_transition 0.20 [current_design]
