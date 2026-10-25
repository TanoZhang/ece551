// Minimal design to confirm Genus can map to the 45nm library.
module adder8 (
    input            clk,
    input      [7:0] a,
    input      [7:0] b,
    output reg [7:0] y
);
  always @(posedge clk) y <= a + b;
endmodule
