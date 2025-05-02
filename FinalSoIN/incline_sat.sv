// Saturates a 13-bit value to 10 bits.
// If MSB = 0 && incline[12:9] != 0  => 0111111111
// else if MSB = 1 && incline[12:9] != 7  => 1000000000
// else incline_sat = incline[9:0]

module incline_sat(
    input [12:0] incline,
    output [9:0] incline_sat
);

// Dataflow verilog to implement the above pseudocode
assign incline_sat[9:0] = ((incline[12]==1'b0) && (incline[12:9] != 3'b000)) ? 10'b0111111111 :
                        ((incline[12]==1'b1) && (incline[12:9] != 3'b111)) ? 10'b1000000000 :
                        incline[9:0];


endmodule