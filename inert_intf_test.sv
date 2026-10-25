module inert_intf_test (clk, RST_n, SS_n, SCLK, MOSI, MISO, INT, LED);

input clk; // Clock signal for the DUT
logic rst_n; // Reset signal for the DUT
logic vld; // Valid data signal from the DUT used as enable
logic [12:0] incline; // Incline data from the DUT
output SS_n;
input RST_n; // Active low reset signal for the DUT
output SCLK; // SPI clock signal
output MOSI; // SPI Master Out Slave In signal
input MISO; // SPI Master In Slave Out signal
input INT; // Interrupt signal from the DUT
output logic [7:0] LED; // LED output for incline data

  // Reset synchronizer (from your reset_synch module)
  rst_synch u_reset (
    .clk  (clk),
    .RST_n(RST_n),
    .rst_n(rst_n)
  );

  // DUT instantiation
  inert_intf u_dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .INT     (INT),
    .SS_n    (SS_n),
    .SCLK    (SCLK),
    .MOSI    (MOSI),
    .MISO    (MISO),
    .incline (incline),
    .vld     (vld)
  );

  // LED latch (captures incline[8:1] when vld)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      LED <= 8'h00;
    else if (vld)
      LED <= incline[8:1];
  end

endmodule