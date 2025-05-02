module inert_intf_test ();

logic clk; // Clock signal for the DUT
logic rst_n; // Reset signal for the DUT
logic vld; // Valid data signal from the DUT used as enable
logic [12:0] incline; // Incline data from the DUT
logic SS_n;
logic RST_n; // Active low reset signal for the DUT
logic SCLK; // SPI clock signal
logic MOSI; // SPI Master Out Slave In signal
logic MISO; // SPI Master In Slave Out signal
logic INT; // Interrupt signal from the DUT
logic [7:0] LED; // LED output for incline data

  // Clock generator: 50 MHz
  initial clk = 0;
  always #10 clk = ~clk;

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

  // No real SPI slave here—just tie MISO low
  assign MISO = 1'b0;

  // LED latch (captures incline[8:1] when vld)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      LED <= 8'h00;
    else if (vld)
      LED <= incline[8:1];
  end

  initial begin
    // ModelSim will record waves automatically; if you want a VCD:

    // initialize inputs
    INT    = 1'b0;
    RST_n  = 1'b0;
    #25;             // hold reset
    RST_n  = 1'b1;   // release reset
    #1400000;    // run long enough to get out of reset state. 

    // pulse INT high to kick off a read sequence
    INT    = 1'b1;
    #20;
    INT    = 1'b0;

    // let it run for a while
    #2000000;

    $stop;
  end

endmodule