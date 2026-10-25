module nonoverlap (
    clk,
    rst_n,
    highIn,
    lowIn,
    highOut,
    lowOut
);
  input logic clk;
  input logic rst_n;
  input logic highIn;
  input logic lowIn;
  output logic highOut;
  output logic lowOut;

  // internal singlas

  logic [4:0] cnt;  //counter
  logic change, previous_low, previous_high, forced_low;
  // any change (even during the dead time) restarts the forced low period
  assign change = (highIn != previous_high) || (lowIn != previous_low);

  //Main sequential logic

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      //initialize all

      cnt <= 0;
      lowOut <= 0;
      highOut <= 0;
      forced_low <= 0;
      previous_low <= 0;
      previous_high <= 0;
    end else begin

      // If input changed -> start (or restart) forced low period
      if (change) begin
        forced_low <= 1;
        cnt <= 0;
        lowOut <= 0;
        highOut <= 0;

        // Forced low peiod logic
      end else if (forced_low) begin
        // during low period, set highOut and lowOut to 0
        lowOut <= 0;
        highOut <= 0;
        cnt <= cnt + 1;

        //exit after 32 cycle
        if (&cnt) begin
          highOut <= highIn;
          lowOut <= lowIn;
          forced_low <= 0;
        end
        // Normal operation when no change
      end else begin
        highOut <= highIn;
        lowOut  <= lowIn;
      end
      // Save current inputs for next change detection
      previous_high <= highIn;
      previous_low  <= lowIn;
    end
  end
endmodule
